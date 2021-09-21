#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

set -e

function _sudo {
    if [ -x "$(command -v sudo)" ] && [ ! -x "$(command -v cygpath)" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

function edit() {
    input_file="$1.in"
    output_file="$1"

    # This is more explicit and reliable than the config file trick
    sed -e "s|[@]PERL[@]|$PERL|g" \
        -e "s|[@]VERSION[@]|$VERSION|g" \
        -e "s|[@]USE_LIB_PMDIR[@]|$USE_LIB_PMDIR|g" "$input_file" >"$output_file"
}

function make_stow() {
    VERSION=2.3.2
    PERL=$(which perl)
    PMDIR="$STOW_ROOT/lib"

    if ! PERL5LIB=$($PERL -V | awk '/@INC/ {p=1; next} (p==1) {print $1}' | grep "$PMDIR" | head -n 1); then
        echo "INFO: Target '$PMDIR' is not in standard include so will be inlined."
    fi

    cd "$STOW_ROOT" || true

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
    echo "✔ Generated Stow binaries and libraries."

    echo "##[cmd] perl -I $STOW_ROOT/lib -I $STOW_ROOT/bin $STOW_ROOT/bin/stow --version"
    perl -I "$STOW_ROOT/lib" -I "$STOW_ROOT/bin" "$STOW_ROOT/bin/stow" --version
}

function _install_dependencies() {
    if [ -x "$(command -v apt-get)" ]; then
        _sudo apt-get update
        _sudo apt-get -y install \
            sudo perl bzip2 gawk curl libssl-dev make patch cpanminus
    elif [ -x "$(command -v apk)" ]; then
        _sudo apk update
        _sudo apk add \
            sudo wget curl unzip xclip \
            build-base gcc g++ make musl-dev openssl-dev zlib-dev \
            perl perl-dev perl-utils perl-app-cpanminus \
            bash openssl
    elif [ -x "$(command -v pacman)" ]; then
        pacman -S --quiet --noconfirm --needed \
            msys2-keyring \
            base-devel libtool libcrypt-devel openssl \
            mingw-w64-x86_64-make mingw-w64-x86_64-gcc mingw-w64-x86_64-binutils mingw-w64-i686-gcc \
            mingw-w64-x86_64-perl \
            mingw-w64-x86_64-poppler
    fi

    perl "$STOW_ROOT/tools/initialize-cpan-config.pl"

    if [ ! -x "$(command -v cpanm)" ]; then
        if [ -x "$(command -v curl)" ]; then
            curl -L --silent "https://cpanmin.us" | _sudo perl - --notest --verbose App::cpanminus
        fi

        if [ ! -x "$(command -v cpanm)" ]; then
            _sudo cpan -i -T App::cpanminus
        fi
    fi

    # We intentionally install as little as possible here to support as many system combinations as
    # possible including MSYS, cygwin, Ubuntu, Alpine, etc. The more libraries we add here the more
    # seemingly obscure issues you could run into e.g., missing 'cc1' or 'poll.h' even when they are
    # in fact installed.
    cpanm --verbose --notest Carp Inline::C

    echo "Installed Perl dependencies."
}

_install_dependencies
make_stow
