#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

# shellcheck source=tools/make-stow.sh
source "$STOW_ROOT/tools/make-stow.sh"

if [ -x "$(command -v pacman)" ]; then
    cpanm --notest Carp Inline::C Test::Output Test::More Test::Exception Win32::Mutex
else
    cpanm --notest Carp Inline::C Test::Output Test::More Test::Exception
fi

prove -I "$STOW_ROOT/t" -I "$STOW_ROOT/lib" -I "$STOW_ROOT/bin" "$STOW_ROOT/t"
