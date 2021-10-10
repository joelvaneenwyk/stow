#!/bin/bash

STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$STOW_ROOT/tools/stow-environment.sh"

function remove_intermediate_doc_files() {
    rm -f "$STOW_ROOT/doc/stow.8" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/stow.log" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/stow.cp" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/stow.aux" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/stow.pdf" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/stow.dvi" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/stow.toc" >/dev/null 2>&1
    rm -f "$STOW_ROOT/doc/manual.pdf"
    rm -rf "$STOW_ROOT/manual.t2d"
    rm -rf "$STOW_ROOT/doc/manual.t2d"
}

function run_tests() {
    if ! make_docs; then
        exit 55
    fi

    if [ ! -f "$STOW_ROOT/Makefile" ]; then
        "$STOW_ROOT/tools/make-clean.sh"
        autoreconf -iv && ./configure
    fi

    if [ -f "$STOW_ROOT/automake/mdate-sh" ]; then
        # We intentionally want splitting so that each space separated part of the
        # date goes into a different argument.
        # shellcheck disable=SC2046
        set $("$STOW_ROOT/automake/mdate-sh" "$STOW_ROOT/doc/stow.texi")
    fi

    (
        printf "@set UPDATED %s %s %s\n" "${1:-0}" "${2:-0}" "${3:-0}"
        echo "@set UPDATED-MONTH ${2:-0} ${3:-0}"
        echo "@set EDITION $STOW_VERSION"
        echo "@set VERSION $STOW_VERSION"
    ) >"$STOW_ROOT/doc/version.texi"

    unset BIBINPUTS BSTINPUTS DVIPSHEADERS INDEXSTYLE MFINPUTS MPINPUTS TEXINPUTS TFMFONTS
    unset COMSPEC ComSpec

    (
        rm -rf "$STOW_ROOT/doc/manual.t2d/version_test"
        mkdir -p "$STOW_ROOT/doc/manual.t2d/version_test"
        cd "$STOW_ROOT/doc/manual.t2d/version_test"
        echo '\input texinfo.tex @bye' >txiversion.tex
        TEXINPUTS=".:$STOW_ROOT/doc/:doc/::" "$TEX" txiversion.tex
    )

    STOW_TEXI2DVI="$STOW_ROOT/doc/texi2dvi.sh"
    #STOW_TEXI2DVI=texi2dvi

    (
        cd "$STOW_ROOT/doc" || true
        # shellcheck disable=SC2016
        PATH=".:$PATH" LOCAL='.' TEXINPUTS='$LOCAL:doc/::' \
            "$STOW_TEXI2DVI" --pdf \
            -I '$LOCAL/ding' \
            --verbose --build=local \
            -o "manual.pdf" "stow.texi"
    )

    _log="$STOW_ROOT/texi2dvi_$(uname -s).log"
    (
        remove_intermediate_doc_files
        rm -f \
            "$STOW_ROOT/doc/stow.info" \
            "$STOW_ROOT/doc/manual_$(uname -s)"*.pdf >/dev/null 2>&1

        # Generate 'doc/stow.info' file needed for generating documentation. The makefile version
        # of this adds the "$STOW_ROOT/automake/missing" prefix to provide additional information
        # if it is unavailable but we skip that here since we do not assume you have already
        # executed 'autoreconf' so the 'missing' tool does not yet exist.
        makeinfo -I "$STOW_ROOT/doc/" -o "$STOW_ROOT/doc/" "$STOW_ROOT/doc/stow.texi"

        if (
            remove_intermediate_doc_files

            # shellcheck disable=SC2030,SC2031
            export TEXINPUTS=".:$STOW_ROOT/automake:/usr/share/automake-1.16:$STOW_ROOT/doc:"

            #export MAKEINFO='sh "$STOW_ROOT/automake/missing" makeinfo -I . -I ./doc  -I doc -I ./doc -I ../'
            unset MAKEINFO

            #cd "$STOW_ROOT" || true
            #COMSPEC="" TEXINPUTS=".:$STOW_ROOT/automake:/usr/share/automake-1.16:$STOW_ROOT/doc:" \
            #    . "$STOW_ROOT/doc/texi2dvi.sh" --pdf \
            #    --debug --verbose \
            #    -o "manual.pdf" "stow.texi"

            cd "$STOW_ROOT" || true
            . "$STOW_ROOT/doc/texi2dvi.sh" --pdf \
                --debug --verbose --build=local \
                -o "doc/manual.pdf" "doc/stow.texi"

            mv "$STOW_ROOT/doc/manual.pdf" "$STOW_ROOT/doc/manual_$(uname -s).pdf"
        ); then
            echo "✔ Used 'doc/stow.texi' to generate 'doc/manual.pdf'"
        else
            exit 5
        fi

        (
            remove_intermediate_doc_files
            rm -f "$STOW_ROOT/doc/manual.pdf" "$STOW_ROOT/doc/manual_$(uname -s).pdf"

            cd "$STOW_ROOT" || true

            # shellcheck disable=SC2030,SC2031
            export TEXINPUTS="$STOW_ROOT/doc;./doc;../;$TEXINPUTS"
            export MAKEINFO='sh automake/missing makeinfo -I . -I ./doc  -I doc -I ./doc -I ../'
            texi2dvi \
                -I "$STOW_ROOT" -I ../ -I doc/ -I ../doc \
                --expand --debug --tidy --pdf --batch \
                -o "./doc/manual.pdf" "./doc/stow.texi"
            mv "$STOW_ROOT/doc/manual.pdf" "$STOW_ROOT/doc/manual_$(uname -s).pdf"
        )

        echo "$_log"

        # shellcheck disable=SC2031
        echo "TeX: $TEX"

        # shellcheck disable=SC2031
        echo "PDFTEX: $PDFTEX"
    ) 2>&1 | tee "$_log"

    if [ ! -f "$STOW_ROOT/doc/manual_$(uname -s)_pdftex.pdf" ] ||
        [ ! -f "$STOW_ROOT/doc/manual_$(uname -s).pdf" ]; then
        return 10
    fi

    return 0
}

run_tests
