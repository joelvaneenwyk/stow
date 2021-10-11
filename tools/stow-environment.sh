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

function normalize_path {
    input_path="${1:-}"

    if [ -n "$input_path" ] && [ -x "$(command -v cygpath)" ]; then
        input_path="$(cygpath "$input_path")"
    fi

    echo "$input_path"

    return 0
}

function resolve_path {
    input_path="$(normalize_path "${1:-}")"
    if [ ! -e "$input_path" ]; then
        input_path=""
    fi
    echo "$input_path"
    return 0
}

function timestamp() {
    echo "##[timestamp] $(date +"%T")"
}

function run_command {
    local command_display

    command_display="$*"
    command_display=${command_display//$'\n'/} # Remove all newlines

    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "[command]$command_display"
    else
        echo "##[cmd] $command_display"
    fi

    "$@"
}

function run_named_command_group() {
    group_name="${1:-}"
    shift

    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::group::$group_name"
    else
        echo "==----------------------"
        echo "## $group_name"
        echo "==----------------------"
    fi

    return_code=0
    timestamp
    if run_command "$@"; then
        echo "✔ Command succeeded."
    else
        return_code=$?
        echo "x Command failed, return code: '$return_code'"
    fi

    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::endgroup::"
    fi

    return $return_code
}

function run_command_group() {
    # Remove all newlines from arguments for display group name
    run_named_command_group "${*//$'\n'/}" "$@"
}

function use_sudo {
    if [ -x "$(command -v sudo)" ] && [ ! -x "$(command -v cygpath)" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

function install_perl_modules() {
    if "$STOW_PERL" -MApp::cpanminus::fatscript -le 1 2>/dev/null; then
        cpan_args=()

        if "$STOW_PERL" -Mlocal::lib -le 1 2>/dev/null; then
            cpan_args+=(-Mlocal::lib="$STOW_PERL_LOCAL_LIB")
        fi

        # shellcheck disable=SC2016
        run_named_command_group "Install Module(s): '$*'" "$STOW_PERL" "${cpan_args[@]}" -MApp::cpanminus::fatscript -le \
            'my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;' -- \
            --skip-installed --skip-satisfied --local-lib "$STOW_PERL_LOCAL_LIB" --notest "$@"
    else
        for package in "$@"; do
            cpan_args=()

            if "$STOW_PERL" -Mlocal::lib -le 1 2>/dev/null; then
                cpan_args+=(-Mlocal::lib="$STOW_PERL_LOCAL_LIB")
            fi

            if ! "$STOW_PERL" "${cpan_args[@]}" -M"$package" -le 1 2>/dev/null; then
                if ! run_named_command_group "Install '$package'" "$STOW_PERL" -MCPAN "${cpan_args[@]}" -e "CPAN::Shell->notest('install', '$package')"; then
                    echo "❌ Failed to install '$package' module."
                    return $?
                fi
            fi
        done
    fi

    return $?
}

# Install everything needed to run 'autoreconf' along with 'make' so
# that we can generate documentation. It is not enough to build and
# run Stow in Perl with full testing dependencies made available.
function install_packages() {
    packages=("$@")

    if [ -x "$(command -v apt-get)" ]; then
        DEBIAN_FRONTEND=noninteractive use_sudo apt-get update \
            --allow-releaseinfo-change
        DEBIAN_FRONTEND=noninteractive use_sudo apt-get -y install \
            --no-install-recommends "${packages[@]}"
    elif [ -x "$(command -v brew)" ]; then
        brew install "${packages[@]}"

        # Needed for tex binaries
        if [ ! -x "$(command -v tex)" ]; then
            brew install --cask basictex
        fi

        # Allows tex to be used right after installation
        if [ -f "/usr/libexec/path_helper" ]; then
            eval "$(/usr/libexec/path_helper)"
        fi

        # Need to make sure that latest texinfo and makeinfo are found first as the version
        # that comes with macOS is too old and you will get errors while building docs with
        # errors like 'makeinfo: invalid option -- c'
        export PATH="/usr/local/opt/texinfo/bin:$PATH"
        if [ -n "${GITHUB_PATH:-}" ]; then
            # Prepend to path so that next GitHub Action will have this updated path as well
            echo "/usr/local/opt/texinfo/bin" >>"$GITHUB_PATH"
            echo "/Library/TeX/texbin/" >>"$GITHUB_PATH"
        fi
    elif [ -x "$(command -v apk)" ]; then
        use_sudo apk update
        use_sudo apk add "${packages[@]}"
    elif [ -x "$(command -v pacman)" ]; then
        run_named_command_group "Install Packages" pacman \
            -S --quiet --noconfirm --needed "${packages[@]}"
    fi
}

function install_system_dependencies() {
    packages=()

    if [ -x "$(command -v apt-get)" ]; then
        packages+=(
            sudo git bzip2 gawk curl patch
            perl cpanminus libssl-dev openssl libz-dev
            build-essential make autotools-dev automake autoconf
            texlive texinfo
        )
    elif [ -x "$(command -v brew)" ]; then
        packages+=(
            autoconf automake libtool texinfo
        )
    elif [ -x "$(command -v apk)" ]; then
        packages+=(
            sudo wget curl unzip bash xclip git
            build-base gcc g++ make musl-dev openssl openssl-dev zlib-dev
            automake autoconf
            perl perl-dev perl-utils perl-app-cpanminus
            texinfo texlive
        )
    elif [ -x "$(command -v pacman)" ]; then
        if [ ! -x "$(command -v git)" ]; then
            packages+=(git)
        fi

        packages+=(
            base-devel gcc make autoconf automake1.16 automake-wrapper libtool
            perl-devel libcrypt-devel openssl openssl-devel
            texinfo texinfo-tex
        )

        if [ -n "${MSYSTEM:-}" ]; then
            packages+=(
                msys2-keyring msys2-runtime-devel msys2-w32api-headers msys2-w32api-runtime
            )
        fi

        if [ -n "${MINGW_PACKAGE_PREFIX:-}" ]; then
            packages+=(
                "$MINGW_PACKAGE_PREFIX-make"
                "$MINGW_PACKAGE_PREFIX-gcc"
                "$MINGW_PACKAGE_PREFIX-binutils"
                "$MINGW_PACKAGE_PREFIX-openssl"
            )

            if [ ! -x "$(command -v tex)" ]; then
                packages+=(
                    "${MINGW_PACKAGE_PREFIX}-texlive-bin"
                    "${MINGW_PACKAGE_PREFIX}-texlive-core"
                )
            fi
        fi
    fi

    install_packages "${packages[@]}"

    unset STOW_ENVIRONMENT_INITIALIZED
}

function initialize_perl() {
    # We call this again to make sure we have the right version of Perl before
    # updating and installing modules.
    update_stow_environment

    if [ -x "$STOW_PERL" ]; then
        if "$STOW_PERL" -MCPAN -le 1 2>/dev/null; then
            (
                echo "yes"
                echo ""
                echo "no"
                echo "exit"
            ) | run_command_group "$STOW_PERL" -MCPAN -e "shell" || true

            run_command_group "$STOW_PERL" "$STOW_ROOT/tools/initialize-cpan-config.pl" || true
        fi

        # Depending on install order it is possible in an MSYS environment to get errors about
        # the 'pl2bat' file being missing. Workaround here is to ensure ExtUtils::MakeMaker is
        # installed and then calling 'pl2bat' to generate it. It should be located under bin
        # folder at '/mingw64/bin/core_perl/pl2bat.bat'
        if [ -n "${MSYSTEM:-}" ]; then
            if [ ! "${MSYSTEM:-}" = "MSYS" ]; then
                export PATH="$PATH:$MSYSTEM_PREFIX/bin:$MSYSTEM_PREFIX/bin/core_perl"
            fi

            # We intentionally use 'which' here as we are on Windows
            # shellcheck disable=SC2230
            if [ -x "$(command -v pl2bat)" ]; then
                pl2bat "$(which pl2bat 2>/dev/null)" 2>/dev/null || true
            fi
        fi

        if ! "$STOW_PERL" -I "$STOW_PERL_LOCAL_LIB" -Mlocal::lib -le 1 2>/dev/null; then
            install_perl_modules 'YAML' 'ExtUtils::MakeMaker' 'ExtUtils::Config' 'local::lib'
        fi

        _perl_local_setup="$("$STOW_PERL" -I "$STOW_PERL_LOCAL_LIB" -Mlocal::lib="$STOW_PERL_LOCAL_LIB")"
        echo "$_perl_local_setup"
        eval "$_perl_local_setup"

        if ! "$STOW_PERL" -Mlocal::lib="$STOW_PERL_LOCAL_LIB" -MApp::cpanminus -le 1 2>/dev/null; then
            local _cpanm
            _cpanm="$STOW_PERL_LOCAL_LIB/cpanm"

            if [ -x "$(command -v curl)" ]; then
                curl -L --silent "https://cpanmin.us/" -o "$_cpanm"
            fi

            chmod +x "$_cpanm"
            run_command "$STOW_PERL" "$_cpanm" --local-lib "$STOW_PERL_LOCAL_LIB" --notest 'App::cpanminus' || true

            # Use 'cpan' to install as a last resort
            if ! "$STOW_PERL" -Mlocal::lib="$STOW_PERL_LOCAL_LIB" -MApp::cpanminus -le 1 2>/dev/null; then
                install_perl_modules "App::cpanminus"
            fi
        fi

        # Install this to silence warning when doing initial configure
        install_perl_modules 'Test::Output'
    fi
}

function install_perl_dependencies() {
    initialize_perl

    modules=()

    # We intentionally install as little as possible here to support as many system combinations as
    # possible including MSYS, cygwin, Ubuntu, Alpine, etc. The more libraries we add here the more
    # seemingly obscure issues you could run into e.g., missing 'cc1' or 'poll.h' even when they are
    # in fact installed.
    modules+=(
        YAML ExtUtils::Config Module::Build::Tiny
        IO::Socket::SSL Net::SSLeay
        Carp Module::Build IO::Scalar
        Test::Harness Test::More Test::Exception Test::Output
        Devel::Cover Devel::Cover::Report::Coveralls
        TAP::Formatter::JUnit
    )

    if [ -n "${MSYSTEM:-}" ]; then
        modules+=(ExtUtils::PL2Bat Inline::C Win32::Mutex)
    fi

    if install_perl_modules "${modules[@]}"; then
        echo "Installed required Perl dependencies."
    else
        echo "Failed to install Perl modules."
        return 88
    fi
}

function install_dependencies() {
    install_system_dependencies
    install_perl_dependencies
}

function make_docs() {
    initialize_perl

    if [ -e "$STOW_ROOT/.git" ]; then
        (
            git -C "$STOW_ROOT" log \
                --format="format:%ad  %aN <%aE>%n%n    * %w(70,0,4)%s%+b%n" \
                --name-status \
                v2.0.2..HEAD | sed 's/^\([A-Z]\)\t/      \1 /'
            cat "$STOW_ROOT/doc/ChangeLog.OLD"
        ) >"$STOW_ROOT/ChangeLog"
        echo "Rebuilt 'ChangeLog' from git commit history."
    else
        echo "Not in a git repository; can't update ChangeLog."
    fi

    if [ -f "$STOW_ROOT/automake/mdate-sh" ]; then
        # We intentionally want splitting so that each space separated part of the
        # date goes into a different argument.
        # shellcheck disable=SC2046
        set $("$STOW_ROOT/automake/mdate-sh" "$STOW_ROOT/doc/stow.texi")
    fi

    (
        printf "@set UPDATED %s %s %s\n" "${1:-0}" "${2:-0}" "${3:-0}"
        echo "@set UPDATED-MONTH ${2:-0} ${3:-0}"
        echo "@set EDITION $STOW_VERSION"
        echo "@set VERSION $STOW_VERSION"
    ) >"$STOW_ROOT/doc/version.texi"

    # Generate 'doc/stow.info' file needed for generating documentation. The makefile version
    # of this adds the "$STOW_ROOT/automake/missing" prefix to provide additional information
    # if it is unavailable but we skip that here since we do not assume you have already
    # executed 'autoreconf' so the 'missing' tool does not yet exist.
    makeinfo -I "$STOW_ROOT/doc/" -o "$STOW_ROOT/doc/" "$STOW_ROOT/doc/stow.texi"

    (
        cd "$STOW_ROOT/doc" || true
        TEXINPUTS="../;." run_command_group pdftex "./stow.texi"
        mv "./stow.pdf" "./manual.pdf"
    )
    echo "✔ Used 'doc/stow.texi' to generate 'doc/manual.pdf'"

    # Add in paths for where to find 'texinfo.tex' which were found using 'find /usr/ -name texinfo.tex'
    PATH=".:$STOW_ROOT:$STOW_ROOT/doc:/usr/share/texmf/tex/texinfo:/usr/share/automake-1.16:$PATH"

    (
        export TEXI2DVI="texi2dvi"
        export TEXINPUTS="../;.;/usr/share/automake-1.16;$STOW_ROOT;$STOW_ROOT/doc;$STOW_ROOT/manual.t2d/version_test;${TEXINPUTS:-}"

        # Valid values of MODE are:
        #
        #   `local'      compile in the current directory, leaving all the auxiliary
        #                files around.  This is the traditional TeX use.
        #   `tidy'       compile in a local *.t2d directory, where the auxiliary files
        #                are left.  Output files are copied back to the original file.
        #   `clean'      same as `tidy', but remove the auxiliary directory afterwards.
        #                Every compilation therefore requires the full cycle.
        export TEXI2DVI_BUILD_MODE=tidy

        export TEXI2DVI_USE_RECORDER=yes

        # Generate 'doc/manual.pdf' using texi2dvi tool. Add '--debug' to print
        # every command exactly like 'set +x' would do.
        #
        # IMPORTANT: We add '--expand' here otherwise we get the error that
        # we "can't find file `txiversion.tex'" which is due to include approach
        # differences on unix versus msys2/windows.
        cd "$STOW_ROOT/doc" || true
        run_command_group "$TEXI2DVI" \
            --pdf --language=texinfo \
            --expand --batch \
            --verbose \
            -I "." -I "$STOW_ROOT" -I "$STOW_ROOT/doc" -I "$STOW_ROOT/doc/manual.t2d/pdf/src" \
            -o "$STOW_ROOT/doc/manual.pdf" \
            "./stow.texi"
    )
}

function update_stow_environment() {
    # Clear out TMP as TEMP may come from Windows and we do not want tools confused
    # if they find both.
    unset TMP
    unset temp
    unset tmp

    export STOW_USE_WINDOWS_TOOLS=0

    local POSITIONAL=()
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
        -w | --use-windows-tools)
            export STOW_USE_WINDOWS_TOOLS=1
            shift # past argument
            ;;
        -d | --debug)
            set -x
            shift # past argument
            ;;
        *)                     # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift              # past argument
            ;;
        esac
    done

    STOW_ROOT="$(normalize_path "${STOW_ROOT:-$(pwd)}")"
    if [ ! -f "$STOW_ROOT/Build.PL" ]; then
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
    export STOW_ROOT

    export STOW_LOCAL_BUILD_ROOT="$STOW_ROOT/.tmp"
    mkdir -p "$STOW_LOCAL_BUILD_ROOT"

    TEX=$(normalize_path "${TEX:-}")
    PDFTEX=$(normalize_path "${PDFTEX:-}")

    case "$(uname -s)" in
    CYGWIN* | MINGW32* | MSYS* | MINGW*)
        _localTexLive="$STOW_LOCAL_BUILD_ROOT/texlive/bin/win32"
        if [ ! -f "$TEX" ] && [ -f "$_localTexLive/tex.exe" ]; then
            TEX="$_localTexLive/tex.exe"
            PDFTEX="$_localTexLive/pdfetex.exe"
        fi
        ;;
    esac

    if [ "${TEX: -4}" == ".exe" ]; then
        if [ ! "$STOW_USE_WINDOWS_TOOLS" = "1" ]; then
            TEX=""
            PDFTEX=""
        else
            export TEXLIVE_ROOT="$STOW_LOCAL_BUILD_ROOT/texlive"
            export TEXLIVE_INSTALL="$STOW_LOCAL_BUILD_ROOT/texlive"
            export TEXDIR="$STOW_LOCAL_BUILD_ROOT/texlive"
            export TEXLIVE_BIN="$TEXDIR/bin/win32"
            export TEXMFCONFIG="$TEXDIR/texmf-config"
            export TEXMFHOME="$TEXDIR/texmf-local"
            export TEXMFLOCAL="$TEXDIR/texmf-local"
            export TEXMFSYSCONFIG="$TEXDIR/texmf-config"
            export TEXMFSYSVAR="$TEXDIR/texmf-var"
            export TEXMFVAR="$TEXDIR/texmf-var"
            export TEXLIVE_INSTALL_PREFIX="$TEXDIR"
            export TEXLIVE_INSTALL_TEXDIR="$TEXDIR"
            export TEXLIVE_INSTALL_TEXMFCONFIG="$TEXDIR/texmf-config"
            export TEXLIVE_INSTALL_TEXMFHOME="$TEXDIR/texmf-local"
            export TEXLIVE_INSTALL_TEXMFLOCAL="$TEXDIR/texmf-local"
            export TEXLIVE_INSTALL_TEXMFSYSCONFIG="$TEXDIR/texmf-config"
            export TEXLIVE_INSTALL_TEXMFSYSVAR="$TEXDIR/texmf-var"
            export TEXLIVE_INSTALL_TEXMFVAR="$TEXDIR/texmf-var"
        fi
    fi

    if [ ! -f "$TEX" ] && _tex="$(which tex 2>/dev/null)"; then
        TEX=$_tex
    fi
    export TEX

    if [ ! -f "$PDFTEX" ] && _pdftex="$(which pdfetex 2>/dev/null)"; then
        PDFTEX=$_pdftex
    fi
    export PDFTEX

    # Find the local Windows install if it exists
    PERL_LOCAL="${PERL_LOCAL:-}"

    while read -r line; do
        # Only print output first time around
        if [ ! "${STOW_ENVIRONMENT_INITIALIZED:-}" == "1" ]; then
            echo "[where.perl] $line"
        fi

        line=$(normalize_path "$line")

        if [ -f "$line" ] && [[ ! "$line" == "$MSYSTEM_PREFIX"* ]] && [[ ! "$line" == /usr/* ]]; then
            PERL_LOCAL="$line"
            break
        fi
    done < <(
        # We manually try to find the version of Perl installed since it is not necessarily
        # automatically added to the PATH.
        _tool_cache="${RUNNER_TOOL_CACHE:-"/c/hostedtoolcache/windows"}"
        _root=$(normalize_path "$_tool_cache/strawberry-perl")
        echo "$_root"
        if [ -d "$_root" ]; then
            find "$_root" -maxdepth 1 -mindepth 1 -type d | (
                while read -r perl_dir; do
                    for variant in "perl/bin/perl.exe" "x64/perl/bin/perl.exe" "x64/perl/bin/perl"; do
                        _perl="$perl_dir/$variant"
                        if [ -e "$_perl" ]; then
                            echo "$_perl"
                        fi
                    done
                done
            )
        fi

        _where=$(normalize_path "${WINDIR:-}\\system32\\where.exe")
        if [ -f "$_where" ]; then
            "$_where" perl
        fi
    )
    export PERL_LOCAL

    # Only favor local Perl install if running on CI
    if [ -n "${GITHUB_ACTIONS:-}" ] || [ "$STOW_USE_WINDOWS_TOOLS" = "1" ]; then
        STOW_PERL="$(normalize_path "${PERL_LOCAL:-${STOW_PERL:-${PERL:-}}}")"
    else
        STOW_PERL=""
    fi

    if [ ! -f "$STOW_PERL" ]; then
        # Update version we use after we install in case the default version should be
        # different e.g., we just installed mingw64 version of perl and want to use that.
        if ! STOW_PERL="$(command -v perl)"; then
            STOW_PERL="$(normalize_path "${PERL_LOCAL:-${PERL:-}}")"
            if [ ! -f "$STOW_PERL" ]; then
                if [ -f "${MSYSTEM_PREFIX:-}/bin/perl" ]; then
                    STOW_PERL="${MSYSTEM_PREFIX:-}/bin/perl"
                else
                    STOW_PERL=""
                fi
            fi
        fi
    fi
    export STOW_PERL
    export STOW_VERSION="0.0.0"

    # Clear out all Perl variables so that they can be reset
    export PMDIR=""
    export PERL=""
    export PERL5LIB=""
    export PERL_C_BIN=""
    export PERL_BIN=""
    export PERL_BIN_C_DIR=""
    export PERL_BIN_DIR=""
    export PERL_LIB=""
    export PERL_LOCAL_LIB_ROOT=""
    export PERL_MB_OPT=""
    export PERL_MM_OPT=""
    export PERL_SITE_BIN_DIR=""

    os_name="$(uname -o | sed 's#/#_#g' | sed 's# #_#g' | awk '{print tolower($0)}')"

    if [ -f "/.dockerenv" ]; then
        os_name="docker_${os_name}"
    elif grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
        os_name="wsl_${os_name}"
    elif [ "$os_name" = "msys" ]; then
        os_name="$(echo "${os_name}_${MSYSTEM}" | awk '{print tolower($0)}')"
    fi
    STOW_PERL_LOCAL_LIB="${STOW_LOCAL_BUILD_ROOT}/perllib/${os_name}"
    mkdir -p "$STOW_PERL_LOCAL_LIB"
    export STOW_PERL_LOCAL_LIB
    export PATH="$STOW_PERL_LOCAL_LIB/bin:$PATH"

    export PERL_LOCAL_LIB_ROOT="$STOW_PERL_LOCAL_LIB"

    # shellcheck disable=SC2016
    PERL5LIB="$PERL_LOCAL_LIB_ROOT"
    PERL5LIB=$(normalize_path "$PERL5LIB")
    export PERL5LIB

    _perl_version="0.0"

    if [ -z "$STOW_PERL" ] || ! _perl_version=$("$STOW_PERL" -e "print substr($^V, 1)"); then
        echo "Failed to find Perl install."
    else
        STOW_VERSION="$("$STOW_PERL" "$STOW_ROOT/tools/get-version")"
        export STOW_VERSION

        PERL_LIB="${PERL_LIB:-}"
        PERL_CPAN_CONFIG="${PERL_CPAN_CONFIG:-}"
        if "$STOW_PERL" -MCPAN -le 1 2>/dev/null; then
            # shellcheck disable=SC2016
            PERL_LIB="$("$STOW_PERL" -MCPAN -e 'use Config; print $Config{privlib};')"
            PERL_LIB="$(resolve_path "$PERL_LIB")"
            [[ -z "$PERL_LIB" ]] && PERL_LIB="${HOME:-}"

            # This is the default location where we can expect to find the config. If it
            # exists then we have already been setup.
            PERL_CPAN_CONFIG="$(resolve_path "$PERL_LIB/CPAN/Config.pm")"
        fi
        export PERL_LIB PERL_CPAN_CONFIG

        if [ ! -d "${PMDIR:-}" ]; then
            PMDIR="$(
                "$STOW_PERL" -V |
                    awk '/@INC:/ {p=1; next} (p==1) {print $1}' |
                    sed 's/\\/\//g' |
                    head -n 1
            )"
        fi
        PMDIR=$(resolve_path "$PMDIR")
        export PMDIR

        # Only find a prefix if PMDIR does not exist on its own
        STOW_SITE_PREFIX="${STOW_SITE_PREFIX:-}"
        if [ ! -d "$PMDIR" ]; then
            siteprefix=""
            eval "$("$STOW_PERL" -V:siteprefix)"
            STOW_SITE_PREFIX=$(normalize_path "$siteprefix")
        fi
        export STOW_SITE_PREFIX

        if [ ! -x "$(command -v gmake)" ]; then
            _perl_bin="$(dirname "$STOW_PERL")"
            export PERL_BIN="$_perl_bin"

            while [ ! "$_perl_bin" == "/" ] && [ -d "$_perl_bin/../" ]; do
                _perl_bin=$(cd "$_perl_bin" && cd .. && pwd)
                if [ ! "$_perl_bin" == "/" ] && [ -d "$_perl_bin/c/bin" ]; then
                    export PERL_C_BIN="$_perl_bin/c/bin"
                    break
                fi
            done
        fi
    fi

    if [ ! "${STOW_ENVIRONMENT_INITIALIZED:-}" == "1" ]; then
        PERL="$STOW_PERL"
        export PERL

        TEX_DIR=""
        if [ -f "$TEX" ]; then
            TEX_DIR="$(dirname "$TEX")"
        fi

        PATH="$PERL_BIN:$PERL_C_BIN:$TEX_DIR:$PATH"
        export PATH

        echo "----------------------------------------"
        echo "Stow Root: '$STOW_ROOT'"
        echo "Stow Version: 'v$STOW_VERSION'"
        echo "Perl: '$PERL'"
        echo "Perl Version: 'v$_perl_version'"

        if [ -n "${PERL_LOCAL:-}" ]; then
            echo "Perl Local: '$PERL_LOCAL'"
        fi

        echo "Perl Lib: '$PERL_LIB'"
        echo "Perl Module (PMDIR): '$PMDIR'"
        echo "TeX: '${TEX:-}'"
        echo "----------------------------------------"

        export STOW_ENVIRONMENT_INITIALIZED="1"
    fi
}

function stow_setup() {
    shopt -s failglob 2>&1 || true

    set -o pipefail >/dev/null 2>&1 || true

    # shellcheck source=tools/make-clean.sh
    bash "$STOW_ROOT/tools/make-clean.sh"

    # shellcheck source=tools/install-dependencies.sh
    bash "$STOW_ROOT/tools/install-dependencies.sh"

    (
        cd "$STOW_ROOT" || true

        # This will create 'configure' script
        run_command autoreconf -iv

        # Run configure to generate 'Makefile' and then run make to create the
        # stow library and binary files e.g., 'stow', 'chkstow', etc.
        run_command ./configure --srcdir="$STOW_ROOT" --with-pmdir="${PMDIR:-}" --prefix="${STOW_SITE_PREFIX:-}"

        run_command make

        # This will create 'Build' or 'Build.bat' depending on platform
        run_command "$STOW_PERL" -I "$STOW_ROOT" -I "$STOW_ROOT/lib" "$STOW_ROOT/Build.PL"

        # shellcheck source=tools/make-stow.sh
        run_command "$STOW_ROOT/tools/make-stow.sh"
    )
}

update_stow_environment "$@"
