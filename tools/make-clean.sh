#!/bin/bash

set -e
#set -x

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function _remove_intermediate_files() {
    rm -rf "$STOW_ROOT/autom4te.cache" >/dev/null 2>&1
    rm -f "$STOW_ROOT/automake/install-sh" >/dev/null 2>&1
    rm -f "$STOW_ROOT/automake/mdate-sh" >/dev/null 2>&1
    rm -f "$STOW_ROOT/automake/missing" >/dev/null 2>&1
    rm -f "$STOW_ROOT/automake/test-driver" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/.dirstamp" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/manual.pdf" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/manual-single.html" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/stamp-vti" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/stow.info" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/stow.8" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/version.texi" >/dev/null 2>&1
    rm -rf "$STOW_ROOT/doc/doc!manual.t2d" >/dev/null 2>&1
    rm -rf "$STOW_ROOT/doc/manual-split" >/dev/null 2>&1
    rm -f "$STOW_ROOT/"config.* >/dev/null 2>&1
    rm -f "$STOW_ROOT/Makefile" >/dev/null 2>&1
    rm -f "$STOW_ROOT/Makefile.in" >/dev/null 2>&1
    rm -f "$STOW_ROOT/MYMETA.json" >/dev/null 2>&1
    rm -f "$STOW_ROOT/MYMETA.yml" >/dev/null 2>&1
    rm -f "$STOW_ROOT/configure" >/dev/null 2>&1
    rm -f "$STOW_ROOT/ChangeLog" >/dev/null 2>&1
    rm -f "$STOW_ROOT/Build" >/dev/null 2>&1
    rm -f "$STOW_ROOT/Build.bat" >/dev/null 2>&1
    rm -f "$STOW_ROOT"/stow-* >/dev/null 2>&1
    rm -f "$STOW_ROOT/stow.log" >/dev/null 2>&1
    rm -f "$STOW_ROOT"/stow.* >/dev/null 2>&1
}

_remove_intermediate_files