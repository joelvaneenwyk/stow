#!/bin/env bash
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

bash "$STOW_ROOT/tools/make-clean.sh"

# shellcheck source=tools/install-dependencies.sh
bash "$STOW_ROOT/tools/install-dependencies.sh"

# Set the 'siteprefix' variable based on configuration settings of Perl
siteprefix=
eval "$(perl -V:siteprefix)"

# Convert to unix path if on Cygwin/MSYS
if [ -x "$(command -v cygpath)" ]; then
    siteprefix=$(cygpath "$siteprefix")
fi

echo "Site prefix: $siteprefix"

(
    cd "$STOW_ROOT" || true

    # This will create 'configure' script
    autoreconf -iv

    # Run configure to generate 'Makefile' and then run make to create the
    # stow library and binary files e.g., 'stow', 'chkstow', etc.
    ./configure --srcdir="$STOW_ROOT" --prefix="${siteprefix:-}" && make

    # This will create 'Build' or 'Build.bat' depending on platform
    perl -I "$STOW_ROOT" -I "$STOW_ROOT/lib" "$STOW_ROOT/Build.PL"

    # shellcheck source=tools/make-stow.sh
    "$STOW_ROOT/tools/make-stow.sh"
)
