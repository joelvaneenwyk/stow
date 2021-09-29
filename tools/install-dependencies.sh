#!/bin/bash

STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && cd ../ && pwd -P)"
source "$STOW_ROOT/tools/stow-lib.sh"

install_dependencies "$@"
