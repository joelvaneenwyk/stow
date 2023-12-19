#!/bin/bash
#
# This file is part of GNU Stow.
#
# GNU Stow is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNU Stow is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see https://www.gnu.org/licenses/.
#

function __print_stack() {
    if [ -n "${BASH:-}" ]; then

        source_index=0
        function_index=1
        callstack_end=${#FUNCNAME[@]}

        local callstack=""
        while ((function_index < callstack_end)); do
            function=${FUNCNAME[$function_index]+"${FUNCNAME[$function_index]}"}
            callstack+=$(printf '\\n    >  %s:%d: %s()' "${BASH_SOURCE[$source_index]}" "${BASH_LINENO[$source_index]}" "${function:-}")
            ((++function_index))
            ((++source_index))
        done

        printf "%b\n" "$callstack" >&2
    fi

    return 0
}

function __safe_exit() {
    _value=$(expr "${1:-}" : '[^0-9]*\([0-9]*\)' 2>/dev/null || :)

    if [ -z "${_value:-}" ]; then
        # Not a supported return value so provide a default
        exit 199
    fi

    # We intentionally do not double quote this because we are expecting
    # this to be a number and exit does not accept strings.
    # shellcheck disable=SC2086
    exit $_value
}

function __trap_error() {
    _retval=$?

    if [ ! "${STOW_DISABLE_TRAP:-}" == "1" ]; then
        _line=${_stow_dbg_last_line:-}

        if [ "${_line:-}" = "" ]; then
            _line="${1:-}"
        fi

        if [ "${_line:-}" = "" ]; then
            _line="[undefined]"
        fi

        # First argument is always the line number even if unused
        shift

        echo "--------------------------------------" >&2

        if [ "${STOW_DEBUG_TRAP_ENABLED:-}" = "1" ]; then
            echo "Error on line #$_line:" >&2
        fi

        # This only exists in a few shells e.g. bash
        # shellcheck disable=SC2039,SC3044
        if _caller="$(caller 2>&1)"; then
            printf " - Caller: '%s'\n" "${_caller:-UNKNOWN}" >&2
        fi

        printf " - Code: '%s'\n" "${_retval:-}" >&2
        printf " - Callstack:" >&2
        __print_stack "$@" >&2
    fi

    # We always exit immediately on error
    __safe_exit ${_retval:-1}
}

function __set_debug_trap() {
    shopt -s extdebug

    # aka. set -T
    set -o functrace

    _stow_dbg_line=
    export _stow_dbg_line

    _stow_dbg_last_line=
    export _stow_dbg_last_line

    # 'ERR' is undefined in POSIX. We also use a somewhat strange looking expansion here
    # for 'BASH_LINENO' to ensure it works if BASH_LINENO is not set. There is a 'gist' of
    # at https://bit.ly/3cuHidf along with more details available at https://bit.ly/2AE2mAC.
    trap '__trap_error "$LINENO" ${BASH_LINENO[@]+"${BASH_LINENO[@]}"}' ERR

    _enable_trace=0
    _bash_debug=0

    # Using debug output is performance intensive as the trap is executed for every single
    # call so only enable it if specifically requested.
    if [ "${STOW_ARG_DEBUG:-0}" = "1" ] && [ -z "${BATS_TEST_NAME:-}" ]; then
        # Redirect only supported in Bash versions after 4.1
        if [ "$BASH_VERSION_MAJOR" -eq 4 ] && [ "$BASH_VERSION_MINOR" -ge 1 ]; then
            _enable_trace=1
        elif [ "$BASH_VERSION_MAJOR" -gt 4 ]; then
            _enable_trace=1
        fi

        if [ "$_enable_trace" = "1" ]; then
            trap '[[ "${FUNCNAME:-}" == "__trap_error" ]] || {
                    _stow_dbg_last_line=${_stow_dbg_line:-};
                    _stow_dbg_line=${LINENO:-};
                }' DEBUG || true

            _bash_debug=1

            # Error tracing (sub shell errors) only work properly in version >=4.0 so
            # we enable here as well. Otherwise errors in subshells can result in ERR
            # trap being called e.g. _my_result="$(errorfunc test)"
            set -o errtrace

            # If set, command substitution inherits the value of the errexit option, instead of unsetting it in the
            # subshell environment. This option is enabled when POSIX mode is enabled.
            shopt -s inherit_errexit

            export STOW_DEBUG_TRAP_ENABLED=1
        fi
    fi

    STOW_DEBUG_TRACE_FILE=""

    # Output trace to file if that is supported
    if [ "$_bash_debug" = "1" ] && [ "$_enable_trace" = "1" ]; then
        STOW_DEBUG_TRACE_FILE="$STOW_HOME/.logs/init.xtrace.$(date +%s).log"
        mkdir -p "$STOW_HOME/.logs"

        # Find a free file descriptor
        log_descriptor=${BASH_XTRACEFD:-19}

        while ((log_descriptor < 31)); do
            if eval "command >&$log_descriptor" >/dev/null 2>&1; then
                eval "exec $log_descriptor>$STOW_DEBUG_TRACE_FILE"
                export BASH_XTRACEFD=$log_descriptor
                set -o xtrace
                break
            fi

            ((++log_descriptor))
        done
    fi

    export STOW_DEBUG_TRACE_FILE
}

function run_command_output_file() {
    output_file=$1
    shift

    local command_display
    command_display="$*"
    command_display=${command_display//$'\n'/} # Remove all newlines

    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "[command]$command_display"
    else
        echo "##[cmd] $command_display"
    fi

    "$@" >"$output_file"
}

function initialize_environment() {
    STOW_ROOT="${STOW_ROOT:-$(pwd)}"

    if [ ! -f "$STOW_ROOT/Build.PL" ]; then
        # If running in a Docker instance, we mount project directory to '/stow'
        if [ -f "/stow/Build.PL" ]; then
            STOW_ROOT="/stow"
        else
            STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && cd ../ && pwd -P)"
        fi

        if [ ! -f "$STOW_ROOT/Build.PL" ]; then
            echo "ERROR: Stow source root not found: '$STOW_ROOT'"
            return 2
        fi
    fi

    PERLBREW_ROOT="${PERLBREW_ROOT:-/usr/local/perlbrew}"

    if [ -x "$(command -v perlbrew)" ]; then
        export STOW_PERL=perl

        if [ ! -f "$PERLBREW_ROOT/etc/bashrc" ]; then
            PERLBREW_ROOT="$HOME/perl5/perlbrew"
        fi

        if [ -f "$PERLBREW_ROOT/etc/bashrc" ]; then
            # Load perlbrew environment that we found.
            # shellcheck disable=SC1090,SC1091
            source "$PERLBREW_ROOT/etc/bashrc"
        else
            echo "ERROR: Failed to find perlbrew setup: '$PERLBREW_ROOT/etc/bashrc'"
            return 3
        fi
    fi

    # shellcheck source=tools/stow-environment.sh
    source "$STOW_ROOT/tools/stow-environment.sh" "$@"
}

function exit_handler() {
    _error=$?

    trap - EXIT

    if [ ! "$_error" = "0" ]; then
        cat <<EOF
=================================================
❌ ERROR: Tests failed. Return code: '$_error'
=================================================

NOTE: To run a specific test, type something like:

    perl -Ilib -Ibin -It t/cli_options.t

Code can be edited on the host and will immediately take effect inside
this container.
EOF

        # Launch a bash instance so we can debug failures if we
        # are running in Docker container.
        if [ -f /.dockerenv ] && [ -z "${GITHUB_ACTIONS:-}" ]; then
            bash
        fi
    fi

    exit "$_error"
}

function test_perl_version() {
    _return_value=0
    _starting_directory="$(pwd)"

    _perl_test_args=(-I "$STOW_PERL_LOCAL_LIB/lib/perl5")

    if activate_local_perl_library; then
        _perl_test_args+=("-Mlocal::lib=""$STOW_PERL_LOCAL_LIB")
    fi

    _perl_version="0.0"

    if ! _perl_version=$("$STOW_PERL" -e "print substr($^V, 1)" | sed 's#\.#_#g'); then
        echo "Failed to get Perl version."
        return 55
    fi

    if ! os_name="$(uname -s | sed 's#\.#_#g' | sed 's#-#_#g' | sed 's#/#_#g' | sed 's# #_#g' | awk '{print tolower($0)}')"; then
        os_name="unknown"
    fi

    if [ -f "/.dockerenv" ]; then
        os_name="docker_${os_name}"
    elif grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
        os_name="wsl_${os_name}"
    elif [ "$(uname -o 2>&1)" = "Msys" ]; then
        os_name="$(echo "msys_${os_name}" | awk '{print tolower($0)}')"
    fi

    _test_result_output_path="$STOW_ROOT/$(
        echo "test_results_${os_name}_${_perl_version}.xml" | awk '{print tolower($0)}'
    )"

    _env=${GITHUB_ENV:-${STOW_PERL_LOCAL_LIB}/.env}
    _cpanm_root="$HOME/.cpanm/work"
    _env_test_path="$_test_result_output_path"

    if [ -x "$(command -v cygpath)" ]; then
        # https://github.com/msys2/setup-msys2/blob/master/main.js
        _cpanm_root=$(cygpath --windows "$_cpanm_root")
        _env_test_path=$(cygpath --windows "$_env_test_path")
    fi

    _cpanm_logs="$_cpanm_root/**/*.log"

    if [ -n "${MSYSTEM:-}" ]; then
        _cpanm_logs="${_cpanm_logs//\//\\}"
    fi

    echo "STOW_CPAN_LOGS=${_cpanm_logs}" | tee -a "$_env"
    echo "STOW_TEST_RESULTS=${_env_test_path}" | tee -a "$_env"

    echo "✔ Exported paths for GitHub Action jobs."

    # Print first non-blank line of Perl version as it includes details of where it
    # was built e.g., 'x86_64-msys-thread-multi'
    "$STOW_PERL" "${_perl_test_args[@]}" --version | sed -e '/^[ \t]*$/d' -e 's/^[ \t]*//' | head -n 1

    # Remove all intermediate files before we start to ensure a clean test
    run_command_group "$STOW_ROOT/tools/make-clean.sh"

    if ! cd "$STOW_ROOT"; then
        echo "ERROR: Failed to change directory to '$STOW_ROOT'"
        return 1
    fi

    # Run auto reconfigure ('autoreconf') to generate 'configure' script
    if ! run_command_group autoreconf --install --verbose; then
        echo "ERROR: Failed to run 'autoreconf' to generate 'configure' script."
        return 2
    fi

    # Run 'configure' to generate Makefile
    run_command_group ./configure --prefix="" --with-pmdir="$STOW_PERL_LOCAL_LIB"

    run_command_group make

    # shellcheck disable=SC2016
    if run_command_output_file "$_test_result_output_path" \
        "$STOW_PERL" "${_perl_test_args[@]}" -MApp::Prove \
        -le 'my $c = App::Prove->new; $c->process_args(@ARGV); $c->run;' -- \
        --formatter "TAP::Formatter::JUnit" \
        --norc --timer --verbose --normalize --parse \
        -I "$STOW_PERL_LOCAL_LIB/lib/perl5" \
        -I t/ -I lib/ -I bin/ \
        "$STOW_ROOT/t"; then
        # If file is empty, tests failed so report an error
        if [ ! -s "$_test_result_output_path" ]; then
            echo "❌ Tests failed. Test result file empty: '$_test_result_output_path"
            _return_value=77
        else
            echo "✔ Generated test results: '$_test_result_output_path'"

            # Reset to default Perl install
            unset PERL5LIB PERL_MB_OPT PERL_MM_OPT PERL_LOCAL_LIB_ROOT

            # Remove the local library path
            _local_bin="$STOW_PERL_LOCAL_LIB/bin"
            PATH=":$PATH:"
            PATH="${PATH//:$_local_bin:/:}"
            PATH="${PATH#:}"
            PATH="${PATH%:}"
            export PATH

            export PERL="$STOW_PERL"

            run_command_group make cpanm

            rm -f "$STOW_ROOT/Build" "$STOW_ROOT/Build.bat" >/dev/null 2>&1

            # Ignore line that contains 'Unsuccessful stat on filename' as the error is sometimes not avoidable depending
            # on files in the project folder.
            if run_command_group "$PERL" "${_perl_test_args[@]}" Build.PL 2>&1 | "$PERL" -ne 'print unless /Unsuccessful stat on filename/'; then
                run_command_group ./Build build
                run_command_group ./Build distcheck
            else
                echo "❌ Failed to run 'Build.PL'"
                return 77
            fi

            if [ -f "$STOW_PERL_LOCAL_LIB/bin/cover" ]; then
                _cover="$STOW_PERL_LOCAL_LIB/bin/cover"
            else
                _cover="$(command -v cover)"
            fi

            if [ -f "$_cover" ]; then
                if [ -z "${GITHUB_ENV:-}" ]; then
                    run_command_group "$STOW_PERL" "${_perl_test_args[@]}" "$_cover" -test
                else
                    run_command_group "$STOW_PERL" "${_perl_test_args[@]}" "$_cover" -test -report coveralls
                fi
            else
                echo "WARNING: Missing 'cover' binary: '$_cover'"
            fi

            run_command_group make distcheck
        fi
    else
        _return_value=$?
        echo "❌ Tests failed. Test result file empty: '$_test_result_output_path"
    fi

    cd "$_starting_directory" || true

    return $_return_value
}

function run_stow_tests() {
    initialize_environment "$@"

    LIST_PERL_VERSIONS=0
    PERL_VERSION=""
    no_install=""

    local POSITIONAL=()
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
        -f | --force)
            echo "Forcefully re-installing 'perlbrew' versions."
            shift
            perlbrew_force=1
            ;;
        -b | --bootstrap-only)
            perlbrew_bootstrap_only=1
            shift
            ;;
        list)
            # List available Perl versions
            LIST_PERL_VERSIONS=1
            shift
            ;;
        --no-install)
            no_install=1
            shift
            ;;
        *) # unknown option
            # Interactive run for testing / debugging a particular version
            PERL_VERSION="${PERL_VERSION:-${1:-}}"
            POSITIONAL+=("$1") # save it in an array for later
            shift              # past argument
            ;;
        esac
    done

    # Disable 'unbound variable' errors since 'perlbrew' setup will error
    # out if they are enabled.
    set +o nounset

    # Standard safety protocol.
    set -eo pipefail

    perlbrew_rc="etc/bashrc"

    PERLBREW_ROOT="${PERLBREW_ROOT:-/usr/local/perlbrew}"
    if [ ! -f "$PERLBREW_ROOT/$perlbrew_rc" ]; then
        PERLBREW_ROOT=~/perl5/perlbrew
    fi

    if [ ! -f "$PERLBREW_ROOT/$perlbrew_rc" ]; then
        curl -k -L https://install.perlbrew.pl | bash

        PERLBREW_ROOT="${PERLBREW_ROOT:-/usr/local/perlbrew}"
        if [ ! -f "$PERLBREW_ROOT/$perlbrew_rc" ]; then
            PERLBREW_ROOT=~/perl5/perlbrew
        fi

        if [ ! -f "$PERLBREW_ROOT/$perlbrew_rc" ]; then
            # We want this to output $PERLBREW_ROOT without expansion
            # shellcheck disable=SC2016
            echo "source \"$PERLBREW_ROOT/$perlbrew_rc\"" >>~/.bash_profile
        fi
    fi

    if [ -f "$PERLBREW_ROOT/$perlbrew_rc" ]; then
        # Load perlbrew environment
        # shellcheck disable=SC1090
        source "$PERLBREW_ROOT/$perlbrew_rc"
    fi

    if [ -x "$PERLBREW_ROOT/bin/perlbrew" ] && [ -z "$(command -v perlbrew)" ]; then
        export PATH=$PERLBREW_ROOT/bin:/usr/bin:$PATH
        echo "Added 'perlbrew' to path."
    fi

    perlbrew list

    if perlbrew_list="$(perlbrew list)"; then
        if [ -z "$perlbrew_list" ] || [ "${perlbrew_force:-}" = "1" ]; then
            perlbrew init
            perlbrew --yes install-cpanm
            perlbrew --yes install-patchperl
            perlbrew --yes install-multiple -j 4 --notest \
                perl-5.14.4 \
                perl-5.34.0

            # Cleanup to remove any temporary files.
            perlbrew clean
        fi

        echo "Initialized 'perlbrew' environment: '$PERLBREW_ROOT/$perlbrew_rc'"
    else
        echo "ERROR: Failed to find 'perlbrew' binary: '$PERLBREW_ROOT'"
        return 5
    fi

    # Standard safety protocol but do this after we setup perlbrew otherwise
    # we get errors with unbound variables
    set -euo pipefail
    shopt -s inherit_errexit nullglob >/dev/null 2>&1 || true
    trap exit_handler EXIT

    __set_debug_trap

    if [ -x "$(command -v perlbrew)" ]; then
        STOW_PERL=perl
    else
        STOW_PERL="${STOW_PERL:-${PERL:-perl}}"
    fi
    export STOW_PERL

    if [ ! "$LIST_PERL_VERSIONS" == "1" ] && [ ! "$no_install" == "1" ]; then
        if install_system_dependencies; then
            echo "Finished installation of system dependencies."
        else
            echo "Failed to install dependencies."
            return 4
        fi
    else
        echo "Skipped install of system dependencies."
    fi

    if [ "$LIST_PERL_VERSIONS" == "1" ]; then
        echo "Listing Perl versions available from perlbrew ..."
        perlbrew list
    else
        versions=()

        if [ -n "${PERL_VERSION// /}" ]; then
            # Test a specific version requested via $PERL_VERSION environment
            # variable.  Make sure set -e doesn't cause us to bail on failure
            # before we start an interactive shell.
            echo "Testing Perl version: $PERL_VERSION"
            versions=("$PERL_VERSION")
        else
            while IFS='' read -r line; do
                versions+=("$line")
            done < <(perlbrew list | sed 's/ //g' | sed 's/\*//g')
            echo "Testing all versions from 'perlbrew' list: ${versions[*]}"
        fi

        for input_perl_version in "${versions[@]}"; do
            printf "\n==========================================\n"
            echo "Test version: $input_perl_version"

            # Use the version of Perl passed in if 'perlbrew' is installed
            if [ -n "$(command -v perlbrew)" ]; then
                # Disable 'unbound variable' errors since 'perlbrew' setup will error
                # out if they are enabled.
                set +o nounset

                perlbrew use "$input_perl_version"
            fi

            perl -V:version
            command -v perl
            printf "==========================================\n\n"

            # Install Perl dependencies on this particular version of Perl in case
            # that has not been done yet.
            if install_perl_dependencies; then
                echo "Installed dependencies: $input_perl_version"
            else
                install_result=$?
                echo "Failed to install dependencies."
                return $install_result
            fi

            if [ "${perlbrew_bootstrap_only:-}" = "1" ]; then
                echo "Skipped testing for bootstrap: $input_perl_version"
                continue
            fi

            if test_perl_version "$input_perl_version"; then
                echo "Finished testing version: $input_perl_version"
            else
                return 4
            fi

            # We intentionally do not 'make distclean' if testing a specific version since
            # we probably want to debug this Perl version interactively.
            if [ ! "${perlbrew_bootstrap_only:-}" = "1" ] && [ -z "$PERL_VERSION" ] && [ -z "${GITHUB_ENV:-}" ]; then
                run_command_group make distclean
            fi
        done
    fi

    echo "✔ Tests succeeded."
}

run_stow_tests "$@"
