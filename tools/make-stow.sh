#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function edit() {
    input_file="$1.in"
    output_file="$1"

    # This is more explicit and reliable than the config file trick
    sed -e "s|[@]STOW_PERL[@]|$STOW_PERL|g" \
        -e "s|[@]VERSION[@]|$STOW_VERSION|g" \
        -e "s|[@]USE_LIB_PMDIR[@]|$USE_LIB_PMDIR|g" "$input_file" >"$output_file"
}

function make_stow() {
    cd "$STOW_ROOT" || true

    export STOW_VERSION=2.3.2
    export STOW_PERL=$(which perl)

    rm -rf "$STOW_ROOT/_Inline"

    if [ ! -x "$(command -v autoreconf)" ]; then
        PMDIR="$STOW_ROOT/lib"

        if ! PERL5LIB=$($STOW_PERL -V | awk '/@INC/ {p=1; next} (p==1) {print $1}' | grep "$PMDIR" | head -n 1); then
            echo "INFO: Target '$PMDIR' is not in standard include so will be inlined."
        fi

        if [ -n "$PERL5LIB" ]; then
            USE_LIB_PMDIR=""
            echo "Module directory is listed in standard @INC, so everything"
            echo "should work fine with no extra effort."
        else
            USE_LIB_PMDIR="use lib \"$PMDIR\";"
            echo "This is *not* in the built-in @INC, so the"
            echo "front-end scripts will have an appropriate \"use lib\""
            echo "line inserted to compensate."
        fi

        edit "$STOW_ROOT/bin/chkstow"
        edit "$STOW_ROOT/bin/stow"
        edit "$STOW_ROOT/lib/Stow.pm"
        edit "$STOW_ROOT/lib/Stow/Util.pm"
    else
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
    fi

    echo "✔ Generated Stow binaries and libraries."

    echo "##[cmd] perl -I $STOW_ROOT/lib -I $STOW_ROOT/bin $STOW_ROOT/bin/stow --version"
    perl -I "$STOW_ROOT/lib" -I "$STOW_ROOT/bin" "$STOW_ROOT/bin/stow" --version
}

# shellcheck source=./tools/install-dependencies.sh
source "$STOW_ROOT/tools/install-dependencies.sh"

make_stow
