#!/bin/bash

# Clear out TMP as TEMP may come from Windows and we do not want tools confused
# if they find both.
unset TMP
unset temp
unset tmp

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function run_command {
    local cmd
    cmd="$*"
    cmd=${cmd//$'\n'/} # Remove all newlines
    cmd=${cmd%$'\n'}   # Remove trailing newline
    echo "##[cmd] $cmd"
    "$@"
}

function use_sudo {
    if [ -x "$(command -v sudo)" ] && [ ! -x "$(command -v cygpath)" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

function install_perl_packages() {
    if "$STOW_PERL" -MApp::cpanminus -le 1 2>/dev/null; then
        # shellcheck disable=SC2016
        run_command use_sudo "$STOW_PERL" -MApp::cpanminus::fatscript -le \
            'my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;' -- \
            --notest "$@"
    else
        for package in "$@"; do
            run_command use_sudo "$STOW_PERL" -MCPAN -e "CPAN::Shell->notest('install', '$package')"
        done
    fi
}

function install_dependencies() {
    if [ -x "$(command -v apt-get)" ]; then
        use_sudo apt-get update
        use_sudo apt-get -y install \
            sudo perl bzip2 gawk curl libssl-dev make patch cpanminus
    elif [ -x "$(command -v apk)" ]; then
        use_sudo apk update
        use_sudo apk add \
            sudo wget curl unzip xclip \
            build-base gcc g++ make musl-dev openssl-dev zlib-dev \
            perl perl-dev perl-utils perl-app-cpanminus \
            bash openssl
    elif [ -x "$(command -v pacman)" ]; then
        pacman -S --quiet --noconfirm --needed \
            git \
            msys2-keyring msys2-runtime-devel msys2-w32api-headers msys2-w32api-runtime \
            base-devel gcc make autoconf automake1.16 automake-wrapper \
            libtool libcrypt-devel openssl \
            perl perl-devel

        if [ "${MSYSTEM:-}" = "MINGW64" ] || [ "${MSYSTEM:-}" = "MINGW32" ]; then
            pacman -S --quiet --noconfirm --needed \
                mingw-w64-x86_64-perl \
                mingw-w64-x86_64-make mingw-w64-x86_64-gcc mingw-w64-x86_64-binutils
        fi
    fi

    if [ -x "$(command -v cygpath)" ]; then
        echo "CPANM: $(cygpath --windows "${HOME:-}/.cpanm/work/")"
    fi

    # Update version we use after we install in case the default version should be
    # different e.g., we just installed mingw64 version of perl
    STOW_PERL="$(command -v perl)"

    if [ -f "/mingw64/bin/perl" ]; then
        STOW_PERL="/mingw64/bin/perl"
    fi

    PERL="$STOW_PERL"
    export STOW_PERL STOW_VERSION STOW_PERL PERL

    (
        echo "yes"
        echo ""
        echo "no"
        echo "exit"
    ) | run_command use_sudo "$STOW_PERL" -MCPAN -e "shell" || true

    run_command use_sudo "$STOW_PERL" "$STOW_ROOT/tools/initialize-cpan-config.pl" || true

    # Depending on install order it is possible in an MSYS environment to get errors about
    # the 'pl2bat' file being missing. Workaround here is to ensure ExtUtils::MakeMaker is
    # installed and then calling 'pl2bat' to generate it. It should be located under bin
    # folder at '/mingw64/bin/core_perl/pl2bat.bat'
    if [ -n "${MSYSTEM:-}" ]; then
        if [ "${MSYSTEM:-}" = "MINGW64" ]; then
            export PATH="$PATH:/mingw64/bin:/mingw64/bin/core_perl"
        fi

        # We intentionally use 'which' here as we are on Windows
        # shellcheck disable=SC2230
        pl2bat "$(which pl2bat)" 2>/dev/null || true
    fi

    if ! "$STOW_PERL" -MApp::cpanminus -le 1 2>/dev/null; then
        local _cpanm
        _cpanm="$STOW_ROOT/cpanm"

        if [ -x "$(command -v curl)" ]; then
            curl -L --silent "https://cpanmin.us/" -o "$_cpanm"
        fi

        chmod +x "$_cpanm"
        run_command use_sudo "$STOW_PERL" "$_cpanm" --notest App::cpanminus || true
        rm -f "$_cpanm"

        # Use 'cpan' to install as a last resort
        if ! "$STOW_PERL" -MApp::cpanminus -le 1 2>/dev/null; then
            install_perl_packages App::cpanminus || true
        fi
    fi

    # We intentionally install as little as possible here to support as many system combinations as
    # possible including MSYS, cygwin, Ubuntu, Alpine, etc. The more libraries we add here the more
    # seemingly obscure issues you could run into e.g., missing 'cc1' or 'poll.h' even when they are
    # in fact installed.
    install_perl_packages Carp Test::Output

    if [ -n "${MSYSTEM:-}" ]; then
        install_perl_packages ExtUtils::PL2Bat Inline::C
    fi

    echo "Installed required Perl dependencies."
}

function install_optional_dependencies() {
    install_dependencies

    if [ -x "$(command -v apt-get)" ]; then
        use_sudo apt-get -y install \
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
        use_sudo apt-get -y install \
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
