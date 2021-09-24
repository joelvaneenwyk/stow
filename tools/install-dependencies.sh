#!/bin/bash

# Clear out TMP as TEMP may come from Windows and we do not want tools confused
# if they find both.
unset TMP
unset temp
unset tmp

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function _sudo {
    if [ -x "$(command -v sudo)" ] && [ ! -x "$(command -v cygpath)" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

function install_dependencies() {
    export STOW_PERL="$(which perl)"

    if [ -x "$(command -v apt-get)" ]; then
        _sudo apt-get update
        _sudo apt-get -y install \
            sudo perl bzip2 gawk curl libssl-dev make patch cpanminus
    elif [ -x "$(command -v apk)" ]; then
        _sudo apk update
        _sudo apk add \
            sudo wget curl unzip xclip \
            build-base gcc g++ make musl-dev openssl-dev zlib-dev \
            perl perl-dev perl-utils perl-app-cpanminus \
            bash openssl
    elif [ -x "$(command -v pacman)" ]; then
        pacman -S --quiet --noconfirm --needed \
            git perl \
            msys2-keyring \
            msys2-runtime-devel msys2-w32api-headers msys2-w32api-runtime \
            base-devel gcc make autoconf automake1.16 automake-wrapper \
            libtool libcrypt-devel openssl

        if [ "${MSYSTEM:-}" = "MINGW64" ] || [ "${MSYSTEM:-}" = "MINGW32" ]; then
            pacman -S --quiet --noconfirm --needed \
                mingw-w64-x86_64-perl \
                mingw-w64-x86_64-make mingw-w64-x86_64-gcc mingw-w64-x86_64-binutils

            if [ -f "/mingw64/bin/perl" ]; then
                export STOW_PERL="/mingw64/bin/perl"
            fi
        fi
    fi

    if [ ! -e "$HOME/.cpan/CPAN/MyConfig.pm" ]; then
        (
            echo "yes"
            echo ""
            echo "no"
            echo "exit"
        ) | _sudo "$STOW_PERL" -MCPAN -e "shell" || true

        echo ""
        echo "##[cmd] sudo "$STOW_PERL" $STOW_ROOT/tools/initialize-cpan-config.pl"
        _sudo "$STOW_PERL" "$STOW_ROOT/tools/initialize-cpan-config.pl" || true
    fi

    if [ ! -x "$(command -v cpanm)" ]; then
        if [ -x "$(command -v curl)" ]; then
            local _cpanm
            _cpanm="$STOW_ROOT/cpanm"
            curl -L --silent "https://cpanmin.us/" -o "$_cpanm"
            chmod +x "$_cpanm"
            echo "##[cmd] sudo perl $_cpanm --verbose App::cpanminus"
            _sudo "$STOW_PERL" "$_cpanm" --notest App::cpanminus
            rm -f "$_cpanm"
        fi

        # Use 'cpan' to install as a last resort
        if [ ! -x "$(command -v cpanm)" ]; then
            echo "##[cmd] sudo $STOW_PERL -MCPAN -e \"CPAN::Shell->notest('install', 'App::cpanminus'\""
            _sudo "$STOW_PERL" -MCPAN -e "CPAN::Shell->notest('install', 'App::cpanminus')"
        fi
    fi

    if [ ! -x "$(command -v cpanm)" ]; then
        echo "❌ ERROR: 'cpanm' not found."
        return 11
    fi

    if [ -x "$(command -v cygpath)" ]; then
        echo "CPANM: $(cygpath --windows "${HOME:-}/.cpanm/work/")"
    fi

    # Alternative approach allowing a local install
    #_sudo cpanm --local-lib=~/perl5 local::lib && eval "$(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)"

    # We intentionally install as little as possible here to support as many system combinations as
    # possible including MSYS, cygwin, Ubuntu, Alpine, etc. The more libraries we add here the more
    # seemingly obscure issues you could run into e.g., missing 'cc1' or 'poll.h' even when they are
    # in fact installed.
    _sudo cpanm --notest Carp Test::Output ExtUtils::PL2Bat Inline::C

    echo "Installed required Perl dependencies."
}

function install_optional_dependencies() {
    install_dependencies

    if [ -x "$(command -v apt-get)" ]; then
        _sudo apt-get -y install \
            texlive texinfo cpanminus \
            autoconf bzip2 \
            perl \
            gawk curl libssl-dev make patch
    elif [ -x "$(command -v pacman)" ]; then
        pacman -S --quiet --noconfirm --needed \
            msys2-devel msys2-runtime-devel msys2-keyring \
            curl wget \
            base-devel git autoconf automake1.16 automake-wrapper \
            libtool libcrypt-devel openssl

        if [ "${MSYSTEM:-}" = "MINGW64" ]; then
            pacman -S --quiet --noconfirm --needed \
                mingw-w64-x86_64-make mingw-w64-x86_64-gcc mingw-w64-x86_64-binutils \
                mingw-w64-x86_64-perl
        fi
    fi
}

function install_documentation_dependencies() {
    install_dependencies

    if [ -x "$(command -v apt-get)" ]; then
        _sudo apt-get -y install \
            texlive texinfo
    elif [ -x "$(command -v pacman)" ]; then
        pacman -S --quiet --noconfirm --needed \
            texinfo texinfo-tex

        if [ "${MSYSTEM:-}" = "MINGW64" ]; then
            pacman -S --quiet --noconfirm --needed \
                mingw-w64-x86_64-texlive-bin mingw-w64-x86_64-texlive-core \
                mingw-w64-x86_64-texlive-extra-utils \
                mingw-w64-x86_64-poppler
        fi
    fi
}

install_dependencies "$@"
