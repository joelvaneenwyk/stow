#!/bin/bash

set -e

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function _sudo {
    if [ -x "$(command -v sudo)" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

# Clear out TMP as TEMP may come from Windows and we do not want tools confused
# if they find both.
unset TMP
unset temp
unset tmp

if [ -x "$(command -v apt-get)" ]; then
    _sudo apt-get update
    _sudo apt-get -y install \
        texlive texinfo cpanminus \
        autoconf bzip2 \
        gawk curl libssl-dev make patch
elif [ -x "$(command -v pacman)" ]; then
    pacman -S --quiet --noconfirm --needed \
        msys2-devel msys2-runtime-devel msys2-keyring \
        curl wget \
        base-devel git autoconf automake1.16 automake-wrapper libtool libcrypt-devel openssl \
        mingw-w64-x86_64-make mingw-w64-x86_64-gcc mingw-w64-x86_64-binutils mingw-w64-i686-gcc \
        mingw-w64-x86_64-perl \
        mingw-w64-x86_64-poppler
    echo "CPANM: $(cygpath --windows "${HOME:-}/.cpanm/work/")"
fi

if [ ! -f "$HOME/.cpan/CPAN/MyConfig.pm" ]; then
    (
        echo "yes"
        echo ""
        echo "no"
        echo "exit"
    ) | _sudo cpan -T || true

    echo ""
    echo "##[cmd] sudo perl $STOW_ROOT/tools/initialize-cpan-config.pl"
    _sudo perl "$STOW_ROOT/tools/initialize-cpan-config.pl" || true
fi

if [ ! -x "$(command -v cpanm)" ]; then
    if [ -x "$(command -v curl)" ]; then
        echo "##[cmd] curl -L --silent https://cpanmin.us | sudo perl - --verbose App::cpanminus"
        curl -L --silent https://cpanmin.us | _sudo perl - --verbose App::cpanminus
    else
        echo "##[cmd] sudo cpan -i -T App::cpanminus"
        _sudo cpan -i -T App::cpanminus
    fi
fi

if [ -x "$(command -v cpanm)" ]; then
    (
        cd "$STOW_ROOT" || true
        echo "##[cmd] sudo cpanm --installdeps --notest ."
        _sudo cpanm --installdeps --notest .
    )
else
    echo "❌ ERROR: 'cpanm' not found."
    exit 11
fi
