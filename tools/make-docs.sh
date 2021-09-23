#!/bin/bash

function make_docs() {
    STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

    # shellcheck source=tools/install-dependencies.sh
    source "$STOW_ROOT/tools/install-dependencies.sh"

    # shellcheck source=tools/make-clean.sh
    source "$STOW_ROOT/tools/make-clean.sh"

    install_documentation_dependencies

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

make_docs
