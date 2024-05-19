#!/usr/bin/env bash

set -eax

# shellcheck disable=SC3028,SC3054,SC2039
REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$REPO_ROOT/tools/pre-configure.sh"
"$REPO_ROOT/configure"
"$REPO_ROOT/tools/post-configure.sh"

make --directory="$REPO_ROOT" "${1:-test}"
