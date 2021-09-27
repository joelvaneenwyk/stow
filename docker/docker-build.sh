#!/usr/bin/env bash

set -eu

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"
STOW_VERSION=$(perl "$STOW_ROOT/tools/get-version")
DOCKER_BASE_IMAGE="stowtest"
DOCKER_IMAGE="$DOCKER_BASE_IMAGE:$STOW_VERSION"

echo "Building Docker DOCKER_IMAGE $DOCKER_IMAGE ..."
docker build -t "$DOCKER_IMAGE" -f "$STOW_ROOT/docker/Dockerfile" "$STOW_ROOT/docker"
