#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

# shellcheck source=tools/stow-lib.sh
source "$STOW_ROOT/tools/stow-lib.sh"

install_perl_modules Carp IO::Scalar Test::Output Test::More Test::Exception

if [ -n "${MSYSTEM:-}" ]; then
    install_perl_modules Inline::C Win32::Mutex
fi

prove -I "$STOW_ROOT/t" -I "$STOW_ROOT/lib" -I "$STOW_ROOT/bin" "$STOW_ROOT/t"
