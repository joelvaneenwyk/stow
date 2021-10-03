#!/usr/bin/bash
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

# Standard safety protocol
set -ef -o pipefail

STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=tools/stow-environment.sh
source "$STOW_ROOT/tools/stow-environment.sh"

# Set the 'siteprefix' variable based on configuration settings of Perl
siteprefix=
eval "$("$PERL" -V:siteprefix)"

if [ ! -d "${PMDIR:-}" ]; then
    PMDIR="$("$PERL" -V | awk '/@INC/ {p=1; next} (p==1) {print $1}' | sed 's/\\/\//g' | head -n 1)"
fi

# Convert to unix path if on Cygwin/MSYS
if [ -x "$(command -v cygpath)" ]; then
    siteprefix=$(cygpath "$siteprefix")
    PMDIR=$(cygpath "$PMDIR")
fi

echo "Perl: '$PERL'"
echo "Site prefix: '$siteprefix'"
echo "PMDIR: '$PMDIR'"

# Remove the prefix if the PMDIR exists on its own
if [ -d "$PMDIR" ]; then
    siteprefix=""
fi

# shellcheck source=tools/make-clean.sh
bash "$STOW_ROOT/tools/make-clean.sh"

# shellcheck source=tools/install-dependencies.sh
bash "$STOW_ROOT/tools/install-dependencies.sh"

(
    cd "$STOW_ROOT" || true

    # This will create 'configure' script
    run_command autoreconf -iv

    # Run configure to generate 'Makefile' and then run make to create the
    # stow library and binary files e.g., 'stow', 'chkstow', etc.
    run_command ./configure --srcdir="$STOW_ROOT" --with-pmdir="${PMDIR:-}" --prefix="${siteprefix:-}"

    run_command make

    # This will create 'Build' or 'Build.bat' depending on platform
    run_command "$PERL" -I "$STOW_ROOT" -I "$STOW_ROOT/lib" "$STOW_ROOT/Build.PL"

    # shellcheck source=tools/make-stow.sh
    run_command "$STOW_ROOT/tools/make-stow.sh"
)
