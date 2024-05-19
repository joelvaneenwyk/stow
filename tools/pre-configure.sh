#!/bin/sh

set -eax

siteprefix=""
eval "$(perl -V:siteprefix)"

if [ ! -d "$siteprefix" ]; then
    echo "siteprefix not found"
    exit 1
fi

echo "Perl 'siteprefix': $siteprefix"
autoreconf --install
cpanm --notest --sudo Devel::Cover::Report::Coveralls Test::Output IO::Scalar
