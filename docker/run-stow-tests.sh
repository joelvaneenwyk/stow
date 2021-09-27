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

# Load perlbrew environment
# Load before setting safety to keep
# perlbrew scripts from breaking due to
# unset variables.

function test_perl_version() {
    local input_perl_version

    input_perl_version="$1"
    perlbrew use "$input_perl_version"

    # shellcheck disable=SC2005
    echo "$(perl --version)"

    # Install stow
    autoreconf --install
    eval "$(perl -V:siteprefix)"

    # shellcheck disable=SC2154
    ./configure --prefix="$siteprefix" && make
    make cpanm

    # Run tests
    make distcheck
    perl Build.PL
    ./Build build
    cover -test
    ./Build distcheck
}

function run_stow_tests() {
    # Standard safety protocol
    set -ef -o pipefail
    IFS=$'\n\t'

    STOW_ROOT="$(pwd)"

    if [ ! -f "$STOW_ROOT/Build.PL" ]; then
        STOW_ROOT="/stow"
    fi

    if [ ! -f "$STOW_ROOT/Build.PL" ]; then
        STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"
    fi

    if [ ! -f "$STOW_ROOT/Build.PL" ]; then
        echo "ERROR: Stow source root not found: '$STOW_ROOT'"
        return 2
    fi

    export STOW_ROOT
    cd "$STOW_ROOT" || true

    PERLBREW_ROOT="${PERLBREW_ROOT:-/usr/local/perlbrew}"

    if [ ! -f "$PERLBREW_ROOT/etc/bashrc" ]; then
        PERLBREW_ROOT="$HOME/perl5/perlbrew"
    fi

    if [ -f "$PERLBREW_ROOT/etc/bashrc" ]; then
        # shellcheck disable=SC1090,SC1091
        source "$PERLBREW_ROOT/etc/bashrc"
    else
        echo "ERROR: Failed to find perlbrew setup: '$PERLBREW_ROOT/etc/bashrc'"
    fi

    if [[ -n "$LIST_PERL_VERSIONS" ]]; then
        echo "Listing Perl versions available from perlbrew ..."
        perlbrew list
    elif [[ -z "$PERL_VERSION" ]]; then
        echo "Testing all versions ..."
        source "$STOW_ROOT/tools/install-dependencies.sh"

        for input_perl_version in $(perlbrew list | sed 's/ //g' | sed 's/\*//g'); do
            test_perl_version "$input_perl_version"
        done

        make distclean
    else
        echo "Testing with Perl $PERL_VERSION"
        source "$STOW_ROOT/tools/install-dependencies.sh"

        # Test a specific version requested via $PERL_VERSION environment
        # variable.  Make sure set -e doesn't cause us to bail on failure
        # before we start an interactive shell.
        test_perl_version "$PERL_VERSION" || true

        # N.B. Don't distclean since we probably want to debug this Perl
        # version interactively.
        cat <<EOF
To run a specific test, type something like:

    perl -Ilib -Ibin -It t/cli_options.t

Code can be edited on the host and will immediately take effect inside
this container.

EOF

        return 3
    fi
}

if ! run_stow_tests "$@"; then
    bash
fi
