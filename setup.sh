#!/bin/env bash

set -e

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)"

# shellcheck source=tools/install-dependencies.sh
source "$STOW_ROOT/tools/install-dependencies.sh"

# This will create 'configure' script
autoreconf -iv

# Set the 'siteprefix' variable based on configuration settings of perl
siteprefix=
eval "$(perl -V:siteprefix)"
echo "Site prefix (default): $siteprefix"

# Convert to unix path if on Cygwin/MSYS
if [ -x "$(command -v cygpath)" ]; then
    siteprefix=$(cygpath "$siteprefix")
    echo "Site prefix    (unix): $siteprefix"
fi

cd "$STOW_ROOT" || true

# Run configure to generate 'Makefile' and then run make to create the
# stow library and binary files e.g., 'stow', 'chkstow', etc.
./configure --srcdir="$STOW_ROOT" --prefix="${siteprefix:-}" && make

# This will create 'Build' or 'Build.bat' depending on platform
perl -I "$STOW_ROOT" -I "$STOW_ROOT/lib" "$STOW_ROOT/Build.PL"

"$STOW_ROOT/tools/make-stow.sh"

"$STOW_ROOT/tools/run-tests.sh"
