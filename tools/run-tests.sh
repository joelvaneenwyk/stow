#!/bin/bash
#
# This file is part of GNU Stow.
#
# GNU Stow is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNU Stow is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see https://www.gnu.org/licenses/.
#

function initialize_environment() {
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
        export STOW_PERL=perl

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

    # shellcheck source=tools/stow-environment.sh
    source "$STOW_ROOT/tools/stow-environment.sh"
}

function exit_handler() {
    _error=$?

    if [ ! "$_error" = "0" ]; then
        cat <<EOF
=================================================
❌ ERROR: Tests failed. Return code: '$_error'
=================================================

NOTE: To run a specific test, type something like:

    perl -Ilib -Ibin -It t/cli_options.t

Code can be edited on the host and will immediately take effect inside
this container.
EOF

        # Launch a bash instance so we can debug failures if we
        # are running in Docker container.
        if [ -f /.dockerenv ] && [ -z "${GITHUB_ACTIONS:-}" ]; then
            bash
        fi
    fi

    exit "$_error"
}

function run_prove() {
    _result_filename=$(
        echo "test_results_${RUNNER_OS:-$(uname)}_${MSYSTEM:-default}.xml" | awk '{print tolower($0)}'
    )
    test_results_path="$STOW_ROOT/$_result_filename"

    if [ -n "${GITHUB_ENV:-}" ]; then
        echo "STOW_TEST_RESULTS=$test_results_path" >>"$GITHUB_ENV"

        if [ -n "${MSYSTEM:-}" ]; then
            # https://github.com/msys2/setup-msys2/blob/master/main.js
            # shellcheck disable=SC2028
            echo 'STOW_CPAN_LOGS=C:\msys64\home\runneradmin\.cpanm\work\**\*.log' >>"$GITHUB_ENV"
        else
            # shellcheck disable=SC2016
            echo "STOW_CPAN_LOGS=$HOME/.cpanm/work/**/*.log" >>"$GITHUB_ENV"
        fi
    fi

    # shellcheck disable=SC2016
    run_command "$STOW_PERL" -MApp::Prove \
        -le 'my $c = App::Prove->new; $c->process_args(@ARGV); $c->run;' -- \
        --formatter "TAP::Formatter::JUnit" \
        --timer --verbose --normalize --parse \
        t/ >"$test_results_path"
    echo "Test results: '$test_results_path'"

    # If file is empty, tests failed so report an error
    if [ ! -s "$test_results_path" ]; then
        "❌ Tests failed. Test result file empty."
        return 77
    fi
}

function test_perl_version() {
    # Use the version of Perl passed in if 'perlbrew' is installed
    if [ -x "$(command -v perlbrew)" ]; then
        perlbrew use "$1"
    fi

    # Install Perl dependencies on this particular version of Perl in case
    # that has not been done yet.
    install_perl_dependencies

    # Print first non-blank line of Perl version as it includes details of where it
    # was built e.g., 'x86_64-msys-thread-multi'
    "$STOW_PERL" --version | sed -e '/^[ \t]*$/d' -e 's/^[ \t]*//' | head -n 1

    # Remove all intermediate files before we start to ensure a clean test
    run_command_group "$STOW_ROOT/tools/make-clean.sh"

    _starting_directory="$(pwd)"
    if cd "$STOW_ROOT"; then
        eval "$("$STOW_PERL" -V:siteprefix)"
        STOW_SITE_PREFIX=$(normalize_path "${siteprefix:-}")

        # Run auto reconfigure ('autoreconf') to generate 'configure' script
        run_command_group autoreconf --install

        # Run 'configure' to generate Makefile
        run_command_group ./configure --prefix="$STOW_SITE_PREFIX"

        run_command_group make
        run_command_group make distcheck

        run_named_command_group "prove" run_prove

        _cover="$(command -v cover)"

        if [ ! -x "$_cover" ] && [ -x "$STOW_PERL_LOCAL_LIB/bin/cover" ]; then
            _cover="$STOW_PERL_LOCAL_LIB/bin/cover"
        fi

        if [ -x "$_cover" ]; then
            run_command_group "$_cover" -test -report coveralls
        else
            echo "Failed to run cover. Missing binary: '$_cover'"
        fi

        #run_command_group "$STOW_PERL" Build.PL
        #run_command_group ./Build build
        #run_command_group ./Build distcheck

        cd "$_starting_directory" || true
    fi
}

function run_stow_tests() {
    _test_argument="${1:-}"

    LIST_PERL_VERSIONS=0
    PERL_VERSION=""

    if [ -x "$(command -v perlbrew)" ]; then
        STOW_PERL=perl
    else
        STOW_PERL="${STOW_PERL:-${PERL:-perl}}"
    fi
    export STOW_PERL

    if [ "$_test_argument" == "list" ]; then
        # List available Perl versions
        LIST_PERL_VERSIONS=1
    elif [ -n "$_test_argument" ]; then
        # Interactive run for testing / debugging a particular version
        PERL_VERSION="$_test_argument"
    fi

    if [ ! "$LIST_PERL_VERSIONS" == "1" ] && [ ! "$_test_argument" == "--no-install" ]; then
        if ! install_system_dependencies; then
            echo "Failed to install dependencies."
            return 4
        fi
    fi

    if [ "$LIST_PERL_VERSIONS" == "1" ]; then
        echo "Listing Perl versions available from perlbrew ..."
        perlbrew list
    elif [ -z "$PERL_VERSION" ] && [ -x "$(command -v perlbrew)" ]; then
        echo "Testing all Perl versions"

        for input_perl_version in $(perlbrew list | sed 's/ //g' | sed 's/\*//g'); do
            test_perl_version "$input_perl_version"
        done

        if [ -z "${GITHUB_ENV:-}" ]; then
            run_command_group make distclean
        fi
    else
        # Test a specific version requested via $PERL_VERSION environment
        # variable.  Make sure set -e doesn't cause us to bail on failure
        # before we start an interactive shell.
        test_perl_version "$PERL_VERSION"

        # We intentionally do not 'make distclean' since we probably want to
        # debug this Perl version interactively.
    fi

    echo "✔ Tests succeeded."
}

initialize_environment

# Standard safety protocol but do this after we setup perlbrew otherwise
# we get errors with unbound variables
set -euo pipefail
shopt -s inherit_errexit nullglob >/dev/null 2>&1 || true
trap exit_handler EXIT

run_stow_tests "$@"
trap - EXIT
