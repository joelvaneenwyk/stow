#!/bin/bash

# Clear out TMP as TEMP may come from Windows and we do not want tools confused
# if they find both.
unset TMP
unset temp
unset tmp

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"
source "$STOW_ROOT/tools/stow-lib.sh"

install_dependencies "$@"
