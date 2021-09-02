#!/bin/bash

perl -MCPAN -e 'my $c = "CPAN::HandleConfig"; $c->load(doit => 1, autoconfig => 1); $c->edit(prerequisites_policy => "follow"); $c->edit(build_requires_install_policy => "yes"); $c->commit'

(
    echo "yes"
    echo ""
    echo "no"
    echo "exit"
) | cpan
cpan -i -T YAML Test::Output CPAN::DistnameInfo
