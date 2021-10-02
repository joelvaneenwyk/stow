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

function edit() {
    input_file="$1.in"
    output_file="$1"

    # This is more explicit and reliable than the config file trick
    sed -e "s|[@]PERL[@]|$STOW_PERL|g" \
        -e "s|[@]VERSION[@]|$STOW_VERSION|g" \
        -e "s|[@]USE_LIB_PMDIR[@]|$USE_LIB_PMDIR|g" "$input_file" >"$output_file"
}

function make_stow() {
    set -e

    STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && cd ../ && pwd -P)"

    # shellcheck source=./tools/stow-lib.sh
    source "$STOW_ROOT/tools/stow-lib.sh"

    rm -rf "$STOW_ROOT/_Inline"
    rm -f "$STOW_ROOT/bin/chkstow"
    rm -f "$STOW_ROOT/bin/stow"
    rm -f "$STOW_ROOT/lib/Stow.pm"
    rm -f "$STOW_ROOT/lib/Stow/Util.pm"
    echo "✔ Removed output files."

    if [ -x "$(command -v autoreconf)" ]; then
        cd "$STOW_ROOT" || true

        autoreconf --install --verbose
        eval "$("$STOW_PERL" -V:siteprefix)"

        if [ -x "$(command -v cygpath)" ]; then
            siteprefix=$(cygpath "$siteprefix")
        fi

        # shellcheck disable=SC2016
        PERL5LIB=$("$STOW_PERL" -le 'print $INC[0]')
        export PERL5LIB

        echo "Site prefix: ${siteprefix:-NULL}"
        echo "Perl lib: $PERL5LIB"

        ./configure --prefix="${siteprefix:-}" --with-pmdir="$PERL5LIB"
        make bin/stow bin/chkstow lib/Stow.pm lib/Stow/Util.pm
    else
        PMDIR="$STOW_ROOT/lib"

        if ! PERL5LIB=$($STOW_PERL -V | awk '/@INC/ {p=1; next} (p==1) {print $1}' | grep "$PMDIR" | head -n 1); then
            echo "INFO: Target '$PMDIR' is not in standard include so will be inlined."
        fi

        if [ -n "$PERL5LIB" ]; then
            USE_LIB_PMDIR=""
            echo "Module directory is listed in standard @INC, so everything"
            echo "should work fine with no extra effort."
        else
            USE_LIB_PMDIR="use lib \"$PMDIR\";"
            echo "This is *not* in the built-in @INC, so the"
            echo "front-end scripts will have an appropriate \"use lib\""
            echo "line inserted to compensate."
        fi

        edit "$STOW_ROOT/bin/chkstow"
        edit "$STOW_ROOT/bin/stow"
        edit "$STOW_ROOT/lib/Stow.pm"
        edit "$STOW_ROOT/lib/Stow/Util.pm"
    fi

    echo "✔ Generated Stow binaries and libraries."

    echo "##[cmd] $STOW_PERL -I $STOW_ROOT/lib -I $STOW_ROOT/bin $STOW_ROOT/bin/stow --version"
    "$STOW_PERL" -I "$STOW_ROOT/lib" -I "$STOW_ROOT/bin" "$STOW_ROOT/bin/stow" --version

    # Revert build changes and remove intermediate files
    git -C "$STOW_ROOT" restore aclocal.m4 >/dev/null 2>&1 || true
    rm -f "$STOW_ROOT/nul" "$STOW_ROOT/configure~" "$STOW_ROOT/Build.bat" "$STOW_ROOT/Build" >/dev/null 2>&1 || true
    echo "✔ Removed intermediate output files."
}

make_stow
