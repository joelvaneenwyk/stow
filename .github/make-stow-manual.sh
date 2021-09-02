#!/bin/bash

function edit() {
    input_file="$1.in"
    output_file="$1"

    # This is more explicit and reliable than the config file trick
    sed -e "s|[@]PERL[@]|$PERL|g" \
        -e "s|[@]VERSION[@]|$VERSION|g" \
        -e "s|[@]USE_LIB_PMDIR[@]|$USE_LIB_PMDIR|g" "$input_file" >"$output_file"
}

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"
VERSION=2.3.2
PERL=/usr/bin/perl
PMDIR=${prefix:-}/share/perl5/site_perl

if ! PERL5LIB=$($PERL -V | awk '/@INC/ {p=1; next} (p==1) {print $1}' | grep "$PMDIR" | head -n 1); then
    echo "ERROR: Failed to check installed Perl libraries."
    PERL5LIB="$PMDIR"
fi

echo "# Perl modules will be installed to $PMDIR"
echo "#"
if [ -n "$PERL5LIB" ]; then
    USE_LIB_PMDIR=""
    echo "# This is in $PERL's built-in @INC, so everything"
    echo "# should work fine with no extra effort."
else
    USE_LIB_PMDIR="use lib \"$PMDIR\";"
    echo "# This is *not* in $PERL's built-in @INC, so the"
    echo "# front-end scripts will have an appropriate \"use lib\""
    echo "# line inserted to compensate."
fi

echo "#"
echo "# PERL5LIB: $PERL5LIB"

edit "$STOW_ROOT/bin/chkstow"
edit "$STOW_ROOT/bin/stow"
edit "$STOW_ROOT/lib/Stow.pm"
edit "$STOW_ROOT/lib/Stow/Util.pm"
