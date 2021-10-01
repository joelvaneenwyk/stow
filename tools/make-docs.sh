#!/bin/bash

function install_texlive() {
    if [ -x "$(command -v apt-get)" ]; then
        install_system_dependencies texlive texinfo
    elif [ -x "$(command -v pacman)" ]; then
        packages+=(texinfo texinfo-tex)

        if [ -n "${MINGW_PACKAGE_PREFIX:-}" ]; then
            packages+=(
                "$MINGW_PACKAGE_PREFIX-texlive-bin" "$MINGW_PACKAGE_PREFIX-texlive-core"
                "$MINGW_PACKAGE_PREFIX-texlive-extra-utils"
                "$MINGW_PACKAGE_PREFIX-poppler"
            )
        fi

        install_system_dependencies "${packages[@]}"
    fi
}

function run_build_command() {
    echo ""
    echo "----------------------"
    echo "$*"
    echo "----------------------"
    "$@"
}

function make_docs() {
    STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && cd ../ && pwd -P)"

    # shellcheck source=tools/stow-lib.sh
    source "$STOW_ROOT/tools/stow-lib.sh"

    update_stow_environment

    # Install 'TeX Live' so that we have 'tex' and the related
    # tools needed to generate documentation.
    install_texlive

    # shellcheck source=tools/make-clean.sh
    "$STOW_ROOT/tools/make-clean.sh"

    siteprefix=
    eval "$(perl -V:siteprefix)"
    echo "Site prefix (default): $siteprefix"

    if [ -x "$(command -v cygpath)" ]; then
        siteprefix=$(cygpath "$siteprefix")
        echo "Site prefix    (unix): $siteprefix"
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

    # Generate 'doc/stow.info' file needed for generating documentation. The makefile version
    # of this adds the "$STOW_ROOT/automake/missing" prefix to provide additional information
    # if it is unavailable but we skip that here since we do not assume you have already
    # executed 'autoreconf' so the 'missing' tool does not yet exist.
    makeinfo -I "$STOW_ROOT/doc/" -o "$STOW_ROOT/doc/" "$STOW_ROOT/doc/stow.texi"

    (
        cd "$STOW_ROOT/doc" || true
        TEXINPUTS="../;." run_build_command pdftex "./stow.texi"
    )
    echo "✔ Used 'doc/stow.texi' to generate 'doc/stow.pdf'"

    # Add in paths for where to find 'texinfo.tex' which were found using 'find /usr/ -name texinfo.tex'
    export PATH=".:$STOW_ROOT:$STOW_ROOT/doc:/usr/share/texmf/tex/texinfo:/usr/share/automake-1.16:$PATH"

    export TEXI2DVI="texi2dvi"
    export TEXINPUTS="../;.;/usr/share/automake-1.16;$STOW_ROOT;$STOW_ROOT/doc;$STOW_ROOT/manual.t2d/version_test;${TEXINPUTS:-}"

    # Valid values of MODE are:
    #
    #   `local'      compile in the current directory, leaving all the auxiliary
    #                files around.  This is the traditional TeX use.
    #   `tidy'       compile in a local *.t2d directory, where the auxiliary files
    #                are left.  Output files are copied back to the original file.
    #   `clean'      same as `tidy', but remove the auxiliary directory afterwards.
    #                Every compilation therefore requires the full cycle.
    export TEXI2DVI_BUILD_MODE=tidy

    export TEXI2DVI_USE_RECORDER=yes

    # Generate 'doc/manual.pdf' using texi2dvi tool. Add '--debug' to print
    # every command exactly like 'set +x' would do.
    #
    # IMPORTANT: We add '--expand' here otherwise we get the error that
    # we "can't find file `txiversion.tex'" which is due to include approach
    # differences on unix versus msys2/windows.
    (
        cd "$STOW_ROOT/doc" || true
        run_build_command "$TEXI2DVI" \
            --pdf --language=texinfo \
            --expand --batch \
            --verbose \
            -I "." -I "$STOW_ROOT" -I "$STOW_ROOT/doc" -I "$STOW_ROOT/doc/manual.t2d/pdf/src" \
            -o "$STOW_ROOT/doc/manual.pdf" \
            "./stow.texi"
    )
}

make_docs
