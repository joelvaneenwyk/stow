#!/usr/bin/env bash
#
# Test Stow across multiple Perl versions, by executing the
# Docker image built via docker-build.sh.
#
# Usage: ./docker-test.sh [list | PERL_VERSION]
#
# If the first argument is 'list', list available Perl versions.
# If the first argument is a Perl version, test just that version interactively.
# If no arguments are given test all available Perl versions non-interactively.
#

STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && cd ../ && pwd -P)"
STOW_VERSION=$(perl "$STOW_ROOT/tools/get-version")
STOW_DOCKER_ROOT="/stow"
STOW_DOCKER_TESTS="$STOW_DOCKER_ROOT/docker/run-stow-tests.sh"

_test_argument="${1:-}"

if [ -z "$_test_argument" ]; then
    # Normal non-interactive run
    docker run --rm -it \
        -v "$STOW_ROOT:$STOW_DOCKER_ROOT" \
        -w "$STOW_DOCKER_ROOT" \
        "stowtest:$STOW_VERSION" \
        "$STOW_DOCKER_TESTS"
elif [ "$_test_argument" == list ]; then
    # List available Perl versions
    docker run --rm -it \
        -v "$STOW_ROOT:$STOW_DOCKER_ROOT" \
        -w "$STOW_DOCKER_ROOT" \
        -e LIST_PERL_VERSIONS=1 \
        "stowtest:$STOW_VERSION" \
        "$STOW_DOCKER_TESTS"
else
    # Interactive run for testing / debugging a particular version
    docker run --rm -it \
        -v "$STOW_ROOT:$STOW_DOCKER_ROOT" \
        -w "$STOW_DOCKER_ROOT" \
        -e "PERL_VERSION=$_test_argument" \
        "stowtest:$STOW_VERSION" \
        "$STOW_DOCKER_TESTS"
fi
