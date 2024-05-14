#!/bin/sh

autoreconf --install
eval "$(perl -V:siteprefix)"
