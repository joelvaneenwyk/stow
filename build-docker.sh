#!/usr/bin/env bash

set -euax

function build() {
    version="$(./tools/get-version)"
    imagename=stowtest
    image=$imagename:$version

    pushd docker
    echo "Building Docker image $image ..."
    docker build -t "$image" .
    popd
}

build "$@"
