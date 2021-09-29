#!/bin/bash

function initialize_brewperl() {
    STOW_ROOT="${STOW_ROOT:-$(pwd)}"

    if [ ! -f "$STOW_ROOT/Build.PL" ]; then
        if [ -f "/stow/Build.PL" ]; then
            STOW_ROOT="/stow"
        else
            STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && cd ../ && pwd -P)"
        fi

        if [ ! -f "$STOW_ROOT/Build.PL" ]; then
            echo "ERROR: Stow source root not found: '$STOW_ROOT'"
            return 2
        fi
    fi

    PERLBREW_ROOT="${PERLBREW_ROOT:-/usr/local/perlbrew}"

    if [ -x "$(command -v perlbrew)" ]; then
        STOW_PERL=perl

        if [ ! -f "$PERLBREW_ROOT/etc/bashrc" ]; then
            PERLBREW_ROOT="$HOME/perl5/perlbrew"
        fi

        if [ -f "$PERLBREW_ROOT/etc/bashrc" ]; then
            # Load perlbrew environment that we found.
            # shellcheck disable=SC1090,SC1091
            source "$PERLBREW_ROOT/etc/bashrc"
        else
            echo "ERROR: Failed to find perlbrew setup: '$PERLBREW_ROOT/etc/bashrc'"
            return 3
        fi
    fi

    # shellcheck source=tools/stow-lib.sh
    source "$STOW_ROOT/tools/stow-lib.sh"

    update_stow_environment
}

function error_handler() {
    cat <<EOF
=================================================
❌ ERROR: Tests failed. Return code: '$?'
=================================================

NOTE: To run a specific test, type something like:

    perl -Ilib -Ibin -It t/cli_options.t

Code can be edited on the host and will immediately take effect inside
this container.
EOF

    # Launch a bash instance so we can debug failures if we
    # are running in Docker container.
    if [ -f /.dockerenv ]; then
        bash
    fi
}

function test_perl_version() {
    # Use the version of Perl passed in
    if [ -x "$(command -v perlbrew)" ]; then
        perlbrew use "$1"
    fi

    # Install the needed modules.
    install_perl_modules \
        Carp IO::Scalar \
        Devel::Cover::Report::Coveralls \
        Test::More Test::Output Test::Exception

    if [ -n "${MSYSTEM:-}" ]; then
        install_perl_modules Inline::C Win32::Mutex
    fi

    # shellcheck disable=SC2005
    echo "$(perl --version)"

    # Install stow
    autoreconf --install

    eval "$(perl -V:siteprefix)"

    # shellcheck disable=SC2154
    ./configure --prefix="$siteprefix"
    make
    make cpanm

    # Run tests
    make distcheck

    perl Build.PL
    ./Build build
    cover -test
    ./Build distcheck
}

function run_stow_tests() {
    _test_argument="${1:-}"

    LIST_PERL_VERSIONS=0
    PERL_VERSION=""

    if [ "$_test_argument" == "list" ]; then
        # List available Perl versions
        LIST_PERL_VERSIONS=1
    elif [ -n "$_test_argument" ]; then
        # Interactive run for testing / debugging a particular version
        PERL_VERSION="$_test_argument"
    fi

    if [[ "$LIST_PERL_VERSIONS" = "0" ]]; then
        if ! "$STOW_ROOT/tools/install-dependencies.sh"; then
            echo "Failed to install dependencies."
            return 4
        fi

        # Remove all intermediate files before we start to ensure a clean test
        "$STOW_ROOT/tools/make-clean.sh"

        echo "==========================="
        echo ""
    fi

    if [[ "$LIST_PERL_VERSIONS" = "1" ]]; then
        echo "Listing Perl versions available from perlbrew ..."
        perlbrew list
    elif [[ -z "$PERL_VERSION" ]]; then
        echo "Testing all versions ..."

        for input_perl_version in $(perlbrew list | sed 's/ //g' | sed 's/\*//g'); do
            test_perl_version "$input_perl_version"
        done

        make distclean
    else
        echo "Testing with Perl $PERL_VERSION"

        # Test a specific version requested via $PERL_VERSION environment
        # variable.  Make sure set -e doesn't cause us to bail on failure
        # before we start an interactive shell.
        test_perl_version "$PERL_VERSION"

        # We intentionally do not 'make distclean' since we probably want to
        # debug this Perl version interactively.
    fi

    echo "✔ Tests succeeded."

    # We clean up only if we have succeeded because on failure we may want to
    # examine the artifacts and logs.
    "$STOW_ROOT/tools/make-clean.sh"
}

initialize_brewperl

# Standard safety protocol but do this after we setup perlbrew otherwise
# we get errors with unbound variables
set -euo pipefail
shopt -s inherit_errexit nullglob
trap error_handler EXIT

run_stow_tests "$@"
trap - EXIT
