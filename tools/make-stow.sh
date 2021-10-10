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

    # shellcheck source=./tools/stow-environment.sh
    source "$STOW_ROOT/tools/stow-environment.sh"

    rm -rf "$STOW_ROOT/_Inline"
    rm -f "$STOW_ROOT/bin/chkstow"
    rm -f "$STOW_ROOT/bin/stow"
    rm -f "$STOW_ROOT/lib/Stow.pm"
    rm -f "$STOW_ROOT/lib/Stow/Util.pm"
    echo "✔ Removed output files."

    if [ -x "$(command -v autoreconf)" ]; then
        cd "$STOW_ROOT" || true

        # shellcheck disable=SC2016
        PERL5LIB=$("$STOW_PERL" -le 'print $INC[0]')
        PERL5LIB=$(normalize_path "$PERL5LIB")

        echo "Perl: '$STOW_PERL'"
        echo "Perl Lib: '$PERL5LIB'"
        echo "Site Prefix: '${STOW_SITE_PREFIX:-}'"

        run_command autoreconf --install --verbose
        run_command ./configure --prefix="${STOW_SITE_PREFIX:-}" --with-pmdir="$PERL5LIB"
        run_command make bin/stow bin/chkstow lib/Stow.pm lib/Stow/Util.pm
    else
        PMDIR="$STOW_ROOT/lib"

        if ! PERL5LIB=$(
            "$STOW_PERL" -V |
                awk '/@INC:/ {p=1; next} (p==1) {print $1}' |
                sed 's/\\/\//g' |
                grep "$PMDIR" |
                head -n 1
        ); then
            echo "INFO: Target '$PMDIR' is not in standard include so will be inlined."
        fi

        if [ -n "$PERL5LIB" ]; then
            PERL5LIB=$(normalize_path "$PERL5LIB")
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

    run_command "$STOW_PERL" -I "$STOW_ROOT/lib" -I "$STOW_ROOT/bin" "$STOW_ROOT/bin/stow" --version

    # Revert build changes and remove intermediate files
    git -C "$STOW_ROOT" restore aclocal.m4 >/dev/null 2>&1 || true
    rm -f \
        "$STOW_ROOT/nul" "$STOW_ROOT/configure~" \
        "$STOW_ROOT/Build.bat" "$STOW_ROOT/Build" >/dev/null 2>&1 || true
    echo "✔ Removed intermediate output files."
}

make_stow
