#!/bin/bash

autoreconf --install --verbose
eval "$(perl -V:siteprefix)"

if [ -x "$(command -v cygpath)" ]; then
    siteprefix=$(cygpath "$siteprefix")
fi

PERL5LIB=$(perl -le 'print $INC[0]')
export PERL5LIB

echo "Site prefix: ${siteprefix:-NULL}"
echo "Perl lib: $PERL5LIB"

(
    echo "yes"
    echo ""
    echo "no"
    echo "exit"
) | cpan
cpan -i -T YAML Test::Output CPAN::DistnameInfo

./configure --prefix="${siteprefix:-}" --with-pmdir="$PERL5LIB"
make bin/stow bin/chkstow lib/Stow.pm lib/Stow/Util.pm