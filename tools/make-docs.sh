#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function _remove_intermediate_files() {
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
    rm -f "$STOW_ROOT/configure" >/dev/null 2>&1
    rm -f "$STOW_ROOT/ChangeLog" >/dev/null 2>&1
    rm -f "$STOW_ROOT/Build" >/dev/null 2>&1
    rm -f "$STOW_ROOT/Build.bat" >/dev/null 2>&1
    rm -f "$STOW_ROOT"/stow-* >/dev/null 2>&1
    rm -f "$STOW_ROOT/stow.log" >/dev/null 2>&1
    rm -f "$STOW_ROOT"/stow.* >/dev/null 2>&1
}

function _install_documentation_dependencies() {
    if [ -x "$(command -v apt-get)" ]; then
        _sudo apt-get update
        _sudo apt-get -y install \
            texlive texinfo
    elif [ -x "$(command -v pacman)" ]; then
        pacman -S --quiet --noconfirm --needed \
            texinfo texinfo-tex \
            mingw-w64-x86_64-texlive-bin mingw-w64-x86_64-texlive-core mingw-w64-x86_64-texlive-extra-utils
    fi
}

function make_docs() {
    siteprefix=
    eval "$(perl -V:siteprefix)"
    echo "Site prefix (default): $siteprefix"

    if [ -x "$(command -v cygpath)" ]; then
        siteprefix=$(cygpath "$siteprefix")
        echo "Site prefix    (unix): $siteprefix"
    fi

    VERSION=2.3.2

    if [ -f "$STOW_ROOT/automake/mdate-sh" ]; then
        # We intentionally want splitting so that each space separated part of the
        # date goes into a different argument.
        # shellcheck disable=SC2046
        set $("$STOW_ROOT/automake/mdate-sh" "$STOW_ROOT/doc/stow.texi")
    fi

    (
        printf "@set UPDATED %s %s %s\n" "${1:-0}" "${2:-0}" "${3:-0}"
        echo "@set UPDATED-MONTH ${2:-0} ${3:-0}"
        echo "@set EDITION $VERSION"
        echo "@set VERSION $VERSION"
    ) >"$STOW_ROOT/doc/version.texi"

    #PATH=.:$PATH
    #TEXINPUTS=doc/stow.texi
    #TEXINPUTS=."$STOW_ROOT/."$STOW_ROOT/..:$STOW_ROOT/doc:$STOW_ROOT/doc/t2d/version_test:.:/usr/local/share/texmf:$TEXINPUTS
    #MAKEINFO='sh automake/missing makeinfo -I doc'
    #MAKEINFO="$STOW_ROOT/automake/missing" makeinfo -I "$STOW_ROOT/doc/" -o "$STOW_ROOT/doc/" "$STOW_ROOT/doc/stow.texi"

    TEXI2DVI="$STOW_ROOT/tools/texinfo/util/texi2dvi"

    # Generate stow.info
    makeinfo -I ./doc/ -o ./doc/ ./doc/stow.texi

    echo ""
    echo "----------------------"
    echo "pdftex $STOW_ROOT/doc/stow.texi"
    echo "----------------------"
    pdftex "$STOW_ROOT/doc/stow.texi"
    echo "Built PDF manually."

    # find /usr/ -name texinfo.tex
    # /usr/share/texmf/tex/texinfo/texinfo.tex
    # /usr/share/automake-1.16/texinfo.tex

    # -E : Expand
    # --debug : Print every command
    # Generate manual.pdf
    echo ""
    echo "----------------------"
    echo "$TEXI2DVI --expand --batch --pdf -I $STOW_ROOT/doc/ --language=texinfo -o $STOW_ROOT/doc/manual.pdf $STOW_ROOT/doc/stow.texi"
    echo "----------------------"
    "$TEXI2DVI" --expand --batch --pdf -I "$STOW_ROOT/doc/" --language=texinfo -o "$STOW_ROOT/doc/manual.pdf" "$STOW_ROOT/doc/stow.texi"

    #texi2dvi --pdf --batch -I doc/ -o doc/manual.pdf doc/stow.texi
    #texi2dvi --verbose --pdf -I doc/ --language=texinfo -o doc/manual.pdf doc/stow.texi

    rm "$STOW_ROOT"/stow.* >/dev/null 2>&1

    #cd "$STOW_ROOT" || true
    #TEXINPUTS=doc/stow.texi doc/version.texi
    #MAKEINFO='sh automake/missing makeinfo -I doc'
    #texi2dvi --pdf --batch -o doc/manual.pdf doc/stow.texi
    #MAKEINFO='/bin/sh "$STOW_ROOT/automake/missing" makeinfo -I .  -I doc -I "$STOW_ROOT/doc"' \
    #    TEXI2DVI_USE_RECORDER=yes texi2dvi -I . -I doc/ --pdf --batch -o doc/manual.pdf "$STOW_ROOT/doc/stow.texi"
}

# shellcheck source=./tools/install-dependencies.sh
source "$STOW_ROOT/tools/install-dependencies.sh"

_install_documentation_dependencies
_remove_intermediate_files

make_docs
