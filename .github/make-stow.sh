#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

cd "$STOW_ROOT" || true

autoreconf --install --verbose
eval "$(perl -V:siteprefix)"

if [ -x "$(command -v cygpath)" ]; then
    siteprefix=$(cygpath "$siteprefix")
fi

PERL5LIB=$(perl -le 'print $INC[0]')
export PERL5LIB

echo "Site prefix: ${siteprefix:-NULL}"
echo "Perl lib: $PERL5LIB"

./configure --prefix="${siteprefix:-}" --with-pmdir="$PERL5LIB"
make bin/stow bin/chkstow lib/Stow.pm lib/Stow/Util.pm
