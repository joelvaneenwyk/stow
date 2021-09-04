#!/bin/bash

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
fi

_sudo perl -MCPAN -e 'my $c = "CPAN::HandleConfig"; $c->load(doit => 1, autoconfig => 1); $c->edit(prerequisites_policy => "follow"); $c->edit(build_requires_install_policy => "yes"); $c->commit'
_sudo cpan -i -T YAML Test::Output Test::More Test::Exception CPAN::DistnameInfo Module::Build Parse::RecDescent Inline::C
_sudo cpanm -n Devel::Cover::Report::Coveralls
