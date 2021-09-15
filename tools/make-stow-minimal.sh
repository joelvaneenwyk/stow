#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function _sudo {
    if [ -x "$(command -v sudo)" ]; then
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
    cd "$STOW_ROOT" || true

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
    echo "Created Stow libraries."

    perl -I "$STOW_ROOT/lib" -I "$STOW_ROOT/bin" "$STOW_ROOT/bin/stow" --version
}

function _install_dependencies() {
    if [ -x "$(command -v apt-get)" ]; then
        _sudo apt-get update
        _sudo apt-get -y install \
            perl bzip2 gawk curl libssl-dev make patch
    elif [ -x "$(command -v apk)" ]; then
        if [ ! -x "$(command -v sudo)" ]; then
            apk update
            apk add sudo
        else
            sudo apk update
        fi

        sudo apk add \
            wget curl unzip xclip \
            build-base gcc g++ make musl-dev openssl-dev zlib-dev \
            perl perl-dev perl-utils \
            bash openssl
    elif [ -x "$(command -v pacman)" ]; then
        pacman -S --quiet --noconfirm --needed \
            msys2-keyring \
            base-devel libtool libcrypt-devel openssl \
            mingw-w64-x86_64-make mingw-w64-x86_64-gcc mingw-w64-x86_64-binutils \
            mingw-w64-x86_64-perl \
            mingw-w64-x86_64-poppler
    fi
}

function _setup_perl() {
    VERSION=2.3.2
    PERL=$(which perl)
    PMDIR=${prefix:-}/share/perl5/site_perl

    if ! PERL5LIB=$($PERL -V | awk '/@INC/ {p=1; next} (p==1) {print $1}' | grep "$PMDIR" | head -n 1); then
        echo "ERROR: Failed to check installed Perl libraries."
        PERL5LIB="$PMDIR"
    fi

    "$STOW_ROOT/tools/initialize-cpan-config.pl"

    if [ ! -x "$(command -v cpanm)" ]; then
        if [ -x "$(command -v curl)" ]; then
            curl -L https://cpanmin.us | perl - --sudo App::cpanminus
        fi

        if [ ! -x "$(command -v cpanm)" ]; then
            _sudo cpan -i -T App::cpanminus
        fi
    fi

    if [ -x "$(command -v pacman)" ]; then
        _sudo cpanm --notest Carp Inline::C IO::File IO::Scalar Win32::Mutex
    else
        _sudo cpanm --notest Carp Inline::C IO::File IO::Scalar
    fi
}

_install_dependencies
_setup_perl
make_stow
