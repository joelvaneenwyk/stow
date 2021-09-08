#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function make_docs() {
    cd "$STOW_ROOT" || true

    MAKEINFO='/bin/sh ./automake/missing makeinfo -I .  -I doc -I ./doc' \
        TEXI2DVI_USE_RECORDER=yes texi2dvi -I . -I doc/ --pdf --batch -o doc/manual.pdf ./doc/stow.texi
}

# shellcheck source=./tools/install-dependencies.sh
. "$STOW_ROOT/tools/install-dependencies.sh"

if [ -x "$(command -v apt-get)" ]; then
    _sudo apt-get update
    _sudo apt-get -y install \
        texlive texinfo
elif [ -x "$(command -v pacman)" ]; then
    pacman -S --quiet --noconfirm --needed \
        texinfo texinfo-tex \
        mingw-w64-x86_64-texlive-bin mingw-w64-x86_64-texlive-core mingw-w64-x86_64-texlive-extra-utils
fi

make_docs
