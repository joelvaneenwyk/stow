#!/bin/bash

siteprefix=
eval "$(perl -V:siteprefix)"
echo "Site prefix (default): $siteprefix"
siteprefix=$(cygpath "$siteprefix")
echo "Site prefix    (unix): $siteprefix"

#TEXINPUTS=doc/stow.texi
#MAKEINFO='sh automake/missing makeinfo -I doc'
VERSION=2.3.2

(
    # Alternative approach would be `read -ra args < <(./automake/mdate-sh ./doc/stow.texi)`
    # shellcheck disable=SC2046
    set $(./automake/mdate-sh ./doc/stow.texi)
    printf "@set UPDATED %s %s %s\n" "$1" "$2" "$3"
    echo "@set UPDATED-MONTH $2 $3"
    echo "@set EDITION $VERSION"
    echo "@set VERSION $VERSION"
) >./doc/version.texi

# Generate stow.info
./automake/missing makeinfo -I doc/ -o doc/ doc/stow.texi

# Generate manual.pdf
#texi2dvi --pdf --batch -I doc/ -o doc/manual.pdf doc/stow.texi

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)"

export TEX=/mingw64/bin/tex.exe
export TEXINPUTS=../../..:$STOW_ROOT/doc:$STOW_ROOT/doc/t2d/version_test:.:/usr/local/share/texmf:$TEXINPUTS
export PATH=.:$PATH

MAKEINFO=./automake/missing makeinfo -I doc/ -o doc/ doc/stow.texi

# -E --debug
./tools/texinfo/util/texi2dvi -E --verbose --pdf -I ./doc/ --language=texinfo -o ./doc/manual.pdf doc/stow.texi
#texi2dvi --verbose --pdf -I doc/ --language=texinfo -o doc/manual.pdf doc/stow.texi
#autoreconf -iv
#./configure --prefix="${siteprefix:-}" && make doc/stow.pdf
