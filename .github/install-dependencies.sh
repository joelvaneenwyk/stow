#!/bin/bash

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"

function _sudo {
    if [ -x "$(command -v sudo)" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

if [ -x "$(command -v apt-get)" ]; then
    _sudo apt-get update
    _sudo apt-get -y install \
        texlive texinfo cpanminus \
        autoconf bzip2 \
        gawk curl libssl-dev make patch
elif [ -x "$(command -v pacman)" ]; then
    pacman -S --quiet --noconfirm --needed \
        base-devel \
        msys2-devel \
        msys2-runtime-devel \
        msys2-keyring \
        openssl \
        git \
        gcc \
        make \
        autoconf \
        automake1.16 \
        automake-wrapper \
        libtool \
        libcrypt-devel \
        perl
fi

_sudo perl -MCPAN "$STOW_ROOT/.github/initialize-cpan-config.pl"

if [ ! -x "$(command -v cpanm)" ]; then
    _sudo cpan -i -T App::cpanminus
fi

_sudo cpanm --install --notest \
    YAML Test::Output Test::More Test::Exception \
    CPAN::DistnameInfo Module::Build Parse::RecDescent Inline::C \
    Devel::Cover::Report::Coveralls TAP::Formatter::JUnit
