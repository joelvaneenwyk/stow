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

function run_docker() {
    STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && cd ../ && pwd -P)"

    if [ -x "$(command -v cygpath)" ]; then
        STOW_LOCAL_ROOT="$(cygpath -w "$STOW_ROOT")"
    elif [ -x "$(command -v wslpath)" ]; then
        STOW_LOCAL_ROOT="$(wslpath -w "$STOW_ROOT")"
    else
        STOW_LOCAL_ROOT="$STOW_ROOT"
    fi

    STOW_VERSION=$(perl "$STOW_ROOT/tools/get-version")
    STOW_DOCKER_ROOT="/stow"

    _test_argument="${1:-}"

    cd "$STOW_ROOT" || true

    docker_args=(--rm)

    if [ -t 1 ] && [ ! -f /.dockerenv ]; then
        # stdout is a tty so we can run an interactive instance
        docker_args+=(-it)
    fi

    if [ "${1:-}" == "list" ]; then
        # List available Perl versions
        docker_args+=(-e LIST_PERL_VERSIONS=1)
    elif [ -n "${1:-}" ]; then
        # Interactive run for testing / debugging a particular version
        docker_args+=(-e "PERL_VERSION=${1:-}")
    fi

    # Add the second array at the end of the first array
    docker_args+=("stowtest:$STOW_VERSION")

    echo "docker run -v \"$STOW_LOCAL_ROOT:$STOW_DOCKER_ROOT\" ${docker_args[*]}"
    docker run -v "$STOW_LOCAL_ROOT:$STOW_DOCKER_ROOT" "${docker_args[@]}"
}

run_docker "$@"
