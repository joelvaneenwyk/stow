#!/bin/bash

if [ -x "$(command -v sudo)" ]; then
    sudo perl -MCPAN -e 'my $c = "CPAN::HandleConfig"; $c->load(doit => 1, autoconfig => 1); $c->edit(prerequisites_policy => "follow"); $c->edit(build_requires_install_policy => "yes"); $c->commit'
    sudo cpan -i -T YAML Test::Output CPAN::DistnameInfo Module::Build
else
    perl -MCPAN -e 'my $c = "CPAN::HandleConfig"; $c->load(doit => 1, autoconfig => 1); $c->edit(prerequisites_policy => "follow"); $c->edit(build_requires_install_policy => "yes"); $c->commit'
    cpan -i -T YAML Test::Output CPAN::DistnameInfo Module::Build
fi
