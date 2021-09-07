#!/bin/env bash

./tools/install-dependencies.sh

# This will create 'configure' script
autoreconf -iv

# Set the 'siteprefix' variable based on configuration settings of perl
eval "$(perl -V:siteprefix)"

# Run configure to generate 'Makefile' and then run make to create the
# stow library and binary files e.g., 'stow', 'chkstow', etc.
./configure --prefix="${siteprefix:-}" && make

# This will create 'Build' or 'Build.bat' depending on platform
perl Build.PL
