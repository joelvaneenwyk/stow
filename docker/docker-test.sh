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

STOW_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" &>/dev/null && cd ../ && pwd)"
STOW_VERSION=$(perl "$STOW_ROOT/tools/get-version")

_test_argument="${1:-}"

if [ -z "$_test_argument" ]; then
    # Normal non-interactive run
    docker run --rm -it \
        -v "$STOW_ROOT:$STOW_ROOT" \
        -w "$STOW_ROOT" \
        "stowtest:$STOW_VERSION"
elif [ "$_test_argument" == list ]; then
    # List available Perl versions
    docker run --rm -it \
        -v "$STOW_ROOT:$STOW_ROOT" \
        -v "$STOW_ROOT/docker/run-stow-tests.sh:/run-stow-tests.sh" \
        -w "$STOW_ROOT" \
        -e LIST_PERL_VERSIONS=1 \
        "stowtest:$STOW_VERSION"
else
    # Interactive run for testing / debugging a particular version
    docker run --rm -it \
        -v "$STOW_ROOT:$STOW_ROOT" \
        -v "$STOW_ROOT/docker/run-stow-tests.sh:/run-stow-tests.sh" \
        -w "$STOW_ROOT" \
        -e "PERL_VERSION=$_test_argument" \
        "stowtest:$STOW_VERSION"
fi
