#!/bin/bash

autoreconf -iv
eval "$(perl -V:siteprefix)"

if [ -x "$(command -v cygpath)" ]; then
    siteprefix=$(cygpath "$siteprefix")
fi

echo "Site prefix: ${siteprefix:-NULL}"
./configure --prefix="${siteprefix:-}" && make
