#!/bin/bash

(
    echo "yes"
    echo ""
    echo "no"
    echo "exit"
) | cpan
cpan -i -T YAML Test::Output CPAN::DistnameInfo
