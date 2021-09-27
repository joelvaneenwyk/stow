#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"
source "$STOW_ROOT/tools/stow-lib.sh"

install_dependencies "$@"
