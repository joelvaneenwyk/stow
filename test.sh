#!/bin/bash

STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$STOW_ROOT/tools/stow-environment.sh"

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
    export TEXINPUTS=".:$STOW_ROOT/doc/:doc/::"
    /mingw64/bin/tex txiversion.tex
)

#STOW_TEXI2DVI="$STOW_ROOT/doc/texi2dvi.sh"
STOW_TEXI2DVI=texi2dvi

cd "$STOW_ROOT/doc" || true
export PATH=".:$PATH"
export LOCAL='.'
TEXINPUTS='$LOCAL:doc/::' "$STOW_TEXI2DVI" --pdf \
    -I '$LOCAL/ding' \
    --verbose --build=local \
    -o "manual.pdf" "stow.texi"

exit 0

_log="$STOW_ROOT/texi2dvi_$(uname -s).log"
(
    rm -f \
        "$STOW_ROOT/doc/stow.info" \
        "$STOW_ROOT/doc/manual_$(uname -s)"*.pdf >/dev/null 2>&1

    # Generate 'doc/stow.info' file needed for generating documentation. The makefile version
    # of this adds the "$STOW_ROOT/automake/missing" prefix to provide additional information
    # if it is unavailable but we skip that here since we do not assume you have already
    # executed 'autoreconf' so the 'missing' tool does not yet exist.
    makeinfo -I "$STOW_ROOT/doc/" -o "$STOW_ROOT/doc/" "$STOW_ROOT/doc/stow.texi"

    if (
        rm -f "$STOW_ROOT/doc/stow.8" >/dev/null 2>&1
        rm -f "$STOW_ROOT/doc/stow.log" >/dev/null 2>&1
        rm -f "$STOW_ROOT/doc/stow.cp" >/dev/null 2>&1
        rm -f "$STOW_ROOT/doc/stow.aux" >/dev/null 2>&1
        rm -f "$STOW_ROOT/doc/stow.pdf" >/dev/null 2>&1
        rm -f "$STOW_ROOT/doc/stow.dvi" >/dev/null 2>&1
        rm -f "$STOW_ROOT/doc/stow.toc" >/dev/null 2>&1
        rm -f "$STOW_ROOT/doc/manual.pdf" >/dev/null 2>&1
        rm -rf "$STOW_ROOT/manual.t2d"
        rm -rf "$STOW_ROOT/doc/manual.t2d"

        cd "$STOW_ROOT/doc" || true
        #TEXINPUTS="../;." run_command_group pdftex "./stow.texi"
        #mv "$STOW_ROOT/doc/stow.pdf" "$STOW_ROOT/doc/manual_$(uname -s)_pdftex.pdf"
    ); then
        echo "✔ Used 'doc/stow.texi' to generate 'doc/manual.pdf'"

        (
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
        )
    fi

    echo "$_log"
    echo "TeX: $TEX"
    echo "PDFTEX: $PDFTEX"
) 2>&1 | tee "$_log"

if [ ! -f "$STOW_ROOT/doc/manual_$(uname -s)_pdftex.pdf" ] || [ ! -f "$STOW_ROOT/doc/manual_$(uname -s).pdf" ]; then
    exit 10
fi

exit 0
