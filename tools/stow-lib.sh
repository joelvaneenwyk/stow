#!/bin/bash

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

function update_stow_environment() {
    # Update version we use after we install in case the default version should be
    # different e.g., we just installed mingw64 version of perl
    STOW_PERL="$(command -v perl)"

    if [ -f "/mingw64/bin/perl" ]; then
        STOW_PERL="/mingw64/bin/perl"
    fi

    PERL="$STOW_PERL"
    export STOW_PERL STOW_VERSION STOW_PERL PERL

    if [ ! -f "${STOW_PERL:-}" ]; then
        STOW_PERL=$(command -v perl)
    fi

    PERL="$STOW_PERL"
    STOW_VERSION=2.3.2
    export STOW_VERSION STOW_PERL PERL
}

function install_dependencies() {
    if [ -x "$(command -v apt-get)" ]; then
        use_sudo apt-get update
        use_sudo apt-get -y install \
            sudo bzip2 gawk curl libssl-dev make autoconf patch \
            perl cpanmins \
            texlive texinfo
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

    update_stow_environment

    if [ -x "$(command -v cygpath)" ]; then
        echo "CPANM: $(cygpath --windows "${HOME:-}/.cpanm/work/")"
    fi

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

update_stow_environment
