#!/bin/env bash

./tools/install-dependencies.sh

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

# Run configure to generate 'Makefile' and then run make to create the
# stow library and binary files e.g., 'stow', 'chkstow', etc.
./configure --prefix="${siteprefix:-}" && make

# This will create 'Build' or 'Build.bat' depending on platform
perl Build.PL
