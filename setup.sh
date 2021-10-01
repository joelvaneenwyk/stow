#!/bin/env bash

# Standard safety protocol
set -ef -o pipefail

STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=tools/stow-lib.sh
source "$STOW_ROOT/tools/stow-lib.sh"

# shellcheck source=tools/install-dependencies.sh
"$STOW_ROOT/tools/install-dependencies.sh"

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
