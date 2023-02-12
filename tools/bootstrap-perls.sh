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

function setup_perlbrew() {
    # Disable 'unbound variable' errors since 'perlbrew' setup will error
    # out if they are enabled.
    set +o nounset

    # Standard safety protocol.
    set -eo pipefail

    set -x

    if ! VALID_ARGS=$(getopt -o f --long force -- "$@"); then
        echo "WARNING: Failed to parse arguments."
    fi

    eval set -- "$VALID_ARGS"
    while [ $# -gt 0 ]; do
        case "$1" in
        -f | --force)
            echo "Forcefully re-installing 'perlbrew' versions."
            shift
            perlbrew_force_force=1
            ;;
        --)
            shift
            break
            ;;
        esac
    done

    STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && cd ../ && pwd -P)"

    perlbrew_rc="etc/bashrc"

    PERLBREW_ROOT="${PERLBREW_ROOT:-/usr/local/perlbrew}"
    if [ ! -f "$PERLBREW_ROOT/$perlbrew_rc" ]; then
        PERLBREW_ROOT=~/perl5/perlbrew
    fi

    if [ ! -f "$PERLBREW_ROOT/$perlbrew_rc" ]; then
        curl -k -L https://install.perlbrew.pl | bash

        PERLBREW_ROOT="${PERLBREW_ROOT:-/usr/local/perlbrew}"
        if [ ! -f "$PERLBREW_ROOT/$perlbrew_rc" ]; then
            PERLBREW_ROOT=~/perl5/perlbrew
        fi

        # We want this to output $PERLBREW_ROOT without expansion
        # shellcheck disable=SC2016
        echo 'source "$PERLBREW_ROOT/etc/bashrc"' >>~/.bash_profile
    fi

    if [ -f "$PERLBREW_ROOT/$perlbrew_rc" ]; then
        # Load perlbrew environment
        # shellcheck disable=SC1090
        source "$PERLBREW_ROOT/$perlbrew_rc"
        echo "Initialized 'perlbrew' environment."

        if [ -z "$(perlbrew list)" ] || [ "${perlbrew_force_force:-}" = "1" ]; then
            perlbrew init
            perlbrew --yes install-cpanm
            perlbrew --yes install-patchperl
            perlbrew --yes install-multiple -j 4 --notest \
                perl-5.14.4 \
                perl-5.34.0
        fi
    else
        echo "ERROR: Failed to find 'perlbrew' setup: '$PERLBREW_ROOT/$perlbrew_rc'"
        return 5
    fi

    # For each Perl version install required modules.
    for p_version in $(perlbrew list | sed 's/ //g' | sed 's/\*//g'); do
        # Switch to it.
        echo "Installing modules for Perl $p_version"
        perlbrew use "$p_version"

        # Install the needed modules.
        cpanm --installdeps \
            --notest --with-recommends --with-suggests "$STOW_ROOT"
    done

    # Cleanup to remove any temporary files.
    perlbrew clean
}

setup_perlbrew "$@"
