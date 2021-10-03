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

    if [ -n "$input_path" ]; then
        if [ -x "$(command -v cygpath)" ]; then
            input_path="$(cygpath "$input_path")"
        fi
    fi

    if [ ! -e "$input_path" ]; then
        input_path=""
    fi

    echo "$input_path"

    return 0
}

timestamp() {
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

    timestamp
    run_command "$@"

    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::endgroup::"
    fi
}

function run_command_group() {
    local command_display

    command_display="$*"
    command_display=${command_display//$'\n'/} # Remove all newlines

    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::group::$command_display"
    else
        echo "==----------------------"
        echo "##[cmd] $command_display"
        echo "==----------------------"
    fi

    timestamp
    "$@"

    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::endgroup::"
    fi
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
        # shellcheck disable=SC2016
        run_named_command_group "Install Perl Modules" use_sudo "$STOW_PERL" -MApp::cpanminus::fatscript -le \
            'my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;' -- \
            --notest "$@"
    else
        for package in "$@"; do
            if ! run_named_command_group "Install '$package'" use_sudo "$STOW_PERL" -MCPAN -e "CPAN::Shell->notest('install', '$package')"; then
                echo "❌ Failed to install '$package' module."
                return $?
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
        use_sudo apt-get update --allow-releaseinfo-change
        use_sudo apt-get -y install \
            sudo bzip2 gawk curl patch \
            build-essential make autotools-dev automake autoconf \
            texlive texinfo "${packages[@]}"
    elif [ -x "$(command -v brew)" ]; then
        brew install autoconf automake libtool texinfo "${packages[@]}"

        # Needed for tex binaries
        brew install --cask basictex

        # Allows tex to be used right after installation
        eval "$(/usr/libexec/path_helper)"

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
        use_sudo apk add \
            sudo wget curl unzip build-base make bash "${packages[@]}"
    elif [ -x "$(command -v pacman)" ]; then
        if [ ! -x "$(command -v git)" ]; then
            packages+=(git)
        fi

        packages+=(
            msys2-keyring base-devel
            make autoconf automake1.16 automake-wrapper
            texinfo texinfo-tex
        )

        if [ -n "${MINGW_PACKAGE_PREFIX:-}" ]; then
            packages+=(
                "$MINGW_PACKAGE_PREFIX-make"
                "$MINGW_PACKAGE_PREFIX-binutils"
            )
        fi

        if [ ! -x "$(command -v tex)" ]; then
            packages+=(
                "${MINGW_PACKAGE_PREFIX:-mingw-w64-x86_64}-texlive-bin"
                "${MINGW_PACKAGE_PREFIX:-mingw-w64-x86_64}-texlive-core"
            )
        fi

        run_command_group pacman -S --quiet --noconfirm --needed "${packages[@]}"
    fi
}

function install_system_dependencies() {
    packages=("$@")

    if [ -x "$(command -v apt-get)" ]; then
        install_packages \
            sudo bzip2 gawk curl libssl-dev patch \
            build-essential make autotools-dev automake autoconf \
            cpanminus \
            texlive texinfo "${packages[@]}"
    elif [ -x "$(command -v brew)" ]; then
        install_packages autoconf automake libtool texinfo "${packages[@]}"
    elif [ -x "$(command -v apk)" ]; then
        install_packages \
            sudo wget curl unzip xclip \
            build-base gcc g++ make musl-dev openssl-dev zlib-dev \
            perl-dev perl-utils perl-app-cpanminus \
            bash openssl "${packages[@]}"
    elif [ -x "$(command -v pacman)" ]; then
        packages+=(
            msys2-keyring msys2-runtime-devel msys2-w32api-headers msys2-w32api-runtime
            base-devel gcc make autoconf automake1.16 automake-wrapper
            libtool libcrypt-devel openssl openssl-devel
            perl-devel
        )

        if [ -n "${MINGW_PACKAGE_PREFIX:-}" ]; then
            packages+=(
                "$MINGW_PACKAGE_PREFIX-make"
                "$MINGW_PACKAGE_PREFIX-gcc"
                "$MINGW_PACKAGE_PREFIX-binutils"
                "$MINGW_PACKAGE_PREFIX-openssl"
            )
        fi

        install_packages "${packages[@]}"
    fi
}

function initialize_perl() {
    # We call this again to make sure we have the right version of Perl before
    # updating and installing modules.
    update_stow_environment

    (
        echo "yes"
        echo ""
        echo "no"
        echo "exit"
    ) | run_command use_sudo "$STOW_PERL" -MCPAN -e "shell" || true

    run_command use_sudo "$STOW_PERL" "$STOW_ROOT/tools/initialize-cpan-config.pl" || true

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
            pl2bat "$(which pl2bat)" 2>/dev/null || true
        fi
    fi

    if ! "$STOW_PERL" -MApp::cpanminus -le 1 2>/dev/null; then
        local _cpanm
        _cpanm="$STOW_ROOT/cpanm"

        if [ -x "$(command -v curl)" ]; then
            curl -L --silent "https://cpanmin.us/" -o "$_cpanm"
        fi

        chmod +x "$_cpanm"
        run_command use_sudo "$STOW_PERL" "$_cpanm" --notest App::cpanminus || true
        rm -f "$_cpanm"

        # Use 'cpan' to install as a last resort
        if ! "$STOW_PERL" -MApp::cpanminus -le 1 2>/dev/null; then
            install_perl_modules "App::cpanminus" || true
        fi
    fi

    # Install this to silence warning when doing initial configure
    install_perl_modules "Test::Output"
}

function install_perl_dependencies() {
    initialize_perl

    modules=()

    # We intentionally install as little as possible here to support as many system combinations as
    # possible including MSYS, cygwin, Ubuntu, Alpine, etc. The more libraries we add here the more
    # seemingly obscure issues you could run into e.g., missing 'cc1' or 'poll.h' even when they are
    # in fact installed.
    modules+=(
        Carp Module::Build IO::Scalar
        Test::More Test::Exception Test::Output
        Devel::Cover::Report::Coveralls
        TAP::Formatter::JUnit
    )

    if [ -n "${MSYSTEM:-}" ]; then
        modules+=(ExtUtils::PL2Bat Inline::C Win32::Mutex)
    fi

    install_perl_modules "${modules[@]}"

    echo "Installed required Perl dependencies."
}

function install_dependencies() {
    install_system_dependencies "$@"
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
    export PATH=".:$STOW_ROOT:$STOW_ROOT/doc:/usr/share/texmf/tex/texinfo:/usr/share/automake-1.16:$PATH"

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
    (
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

    # Find the local Windows install if it exists
    PERL_LOCAL="${PERL_LOCAL:-}"
    _where=$(normalize_path "${WINDIR:-}\\system32\\where.exe")
    if [ -f "$_where" ]; then
        while read -r line; do
            line=$(normalize_path "$line")

            # Only print output first time around
            if [ ! "${PERL_LOCAL_SEARCH:-}" == "1" ]; then
                echo "[where.perl] $line"
            fi

            if [[ ! "$line" == "$MSYSTEM_PREFIX"* ]] && [[ ! "$line" == /usr/* ]]; then
                PERL_LOCAL="$line"
                break
            fi
        done < <("$_where" perl)
        export PERL_LOCAL_SEARCH="1"
    fi
    export PERL_LOCAL

    # Update version we use after we install in case the default version should be
    # different e.g., we just installed mingw64 version of perl and want to use that.
    STOW_PERL="$(normalize_path "${PERL_LOCAL:-${STOW_PERL:-${PERL:-}}}")"
    if [ ! -f "$STOW_PERL" ]; then
        STOW_PERL="$(command -v perl)"

        if [ ! -f "$STOW_PERL" ] && [ -f "/mingw64/bin/perl" ]; then
            STOW_PERL="/mingw64/bin/perl"
        fi
    fi
    export STOW_PERL

    STOW_VERSION="$("$STOW_PERL" "$STOW_ROOT/tools/get-version")"
    export STOW_VERSION

    # shellcheck disable=SC2016
    PERL_LIB="$("$STOW_PERL" -MCPAN -e 'use Config; print $Config{privlib};')"
    PERL_LIB="$(normalize_path "$PERL_LIB")"
    export PERL_LIB

    # This is the default location where we can expect to find the config. If it
    # exists then we have already been setup.
    PERL_CPAN_CONFIG="$PERL_LIB/CPAN/Config.pm"
    export PERL_CPAN_CONFIG

    if [ ! -d "${PMDIR:-}" ]; then
        PMDIR="$(
            "$STOW_PERL" -V |
                awk '/@INC/ {p=1; next} (p==1) {print $1}' |
                sed 's/\\/\//g' |
                head -n 1
        )"
    fi
    PMDIR=$(normalize_path "$PMDIR")
    export PMDIR

    # Only find a prefix if PMDIR does not exist on its own
    STOW_SITE_PREFIX="${STOW_SITE_PREFIX:-}"
    if [ ! -d "$PMDIR" ]; then
        siteprefix=""
        eval "$("$STOW_PERL" -V:siteprefix)"
        STOW_SITE_PREFIX=$(normalize_path "$siteprefix")
    fi
    export STOW_SITE_PREFIX

    # shellcheck disable=SC2016
    PERL5LIB=$("$STOW_PERL" -le 'print $INC[0]')
    PERL5LIB=$(normalize_path "$PERL5LIB")
    export PERL5LIB

    if [ ! -x "$(command -v gmake)" ]; then
        _perl_bin="$(dirname "$PERL")"

        if [ -d "$_perl_bin/../../c/bin" ]; then
            _perl_c_bin=$(cd "$_perl_bin" && cd ../../c/bin && pwd)
        elif [ -d "$_perl_bin/../../../c/bin" ]; then
            _perl_c_bin=$(cd "$_perl_bin" && cd ../../../c/bin && pwd)
        fi

        if [ -d "$_perl_c_bin" ]; then
            PATH="$_perl_c_bin:$PATH"
            export PATH
        fi
    fi

    if [ ! "${PERL:-}" == "$STOW_PERL" ]; then
        PERL="$STOW_PERL"
        export PERL

        echo "Stow Root: '$STOW_ROOT'"
        echo "Stow Version: 'v$STOW_VERSION'"
        echo "Perl: '$PERL'"

        if [ -n "${PERL_LOCAL:-}" ]; then
            echo "Perl Local: '$PERL_LOCAL'"
        fi

        echo "Perl Lib: '$PERL_LIB'"
        echo "Perl Module (PMDIR): '$PMDIR'"
        echo "----------------------------------------"
    fi
}

update_stow_environment
