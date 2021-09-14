#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function _sudo {
    if [ -x "$(command -v sudo)" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

if [ -x "$(command -v apt-get)" ]; then
    _sudo apt-get update
    _sudo apt-get -y install \
        texlive texinfo cpanminus \
        autoconf bzip2 \
        gawk curl libssl-dev make patch
elif [ -x "$(command -v pacman)" ]; then
    pacman -S --quiet --noconfirm --needed \
        msys2-devel msys2-runtime-devel msys2-keyring \
        base-devel git autoconf automake1.16 automake-wrapper libtool libcrypt-devel openssl \
        mingw-w64-x86_64-make mingw-w64-x86_64-gcc mingw-w64-x86_64-binutils \
        mingw-w64-x86_64-perl \
        mingw-w64-x86_64-poppler
fi

"$STOW_ROOT/tools/initialize-cpan-config.pl"

if [ ! -x "$(command -v cpanm)" ]; then
    if [ -x "$(command -v curl)" ]; then
        curl -L https://cpanmin.us | perl - App::cpanminus
    else
        _sudo cpan -i -T App::cpanminus
    fi
fi

(
    cd "$STOW_ROOT" || true
    cpanm --installdeps --notest .
)
