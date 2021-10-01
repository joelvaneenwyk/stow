#!/bin/bash

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

function run_command_group() {
    local command_display

    command_display="$*"
    command_display=${command_display//$'\n'/} # Remove all newlines

    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::group::$command_display"
    else
        echo "##[cmd] $command_display"
    fi

    "$@"

    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::endgroup::"
    fi
}

function run_build_command() {
    echo ""
    echo "----------------------"
    echo "$*"
    echo "----------------------"
    "$@"
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
        run_command use_sudo "$STOW_PERL" -MApp::cpanminus::fatscript -le \
            'my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;' -- \
            --notest "$@"
    else
        for package in "$@"; do
            echo "::group::cpan install $package"
            if ! run_command use_sudo "$STOW_PERL" -MCPAN -e "CPAN::Shell->notest('install', '$package')"; then
                echo "::endgroup::"
                echo "❌ Failed to install '$package' module."
                return $?
            fi
            echo "::endgroup::"
        done
    fi

    return $?
}

function update_stow_environment() {
    # Early out if environment is already up-to-date
    if [ -d "${STOW_ROOT:-}" ] && [ -n "${STOW_PERL:-}" ]; then
        return 0
    fi

    # Clear out TMP as TEMP may come from Windows and we do not want tools confused
    # if they find both.
    unset TMP
    unset temp
    unset tmp

    STOW_ROOT="${STOW_ROOT:-$(pwd)}"

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

    # Update version we use after we install in case the default version should be
    # different e.g., we just installed mingw64 version of perl
    STOW_PERL="$(command -v perl)"

    if [ -f "/mingw64/bin/perl" ]; then
        STOW_PERL="/mingw64/bin/perl"
    fi

    if [ ! -f "${STOW_PERL:-}" ]; then
        STOW_PERL=$(command -v perl)
    fi

    export STOW_PERL

    PERL="$STOW_PERL"
    export PERL

    STOW_VERSION="$("$STOW_PERL" "$STOW_ROOT/tools/get-version")"
    export STOW_VERSION
}

function install_system_base_dependencies() {
    if [ -x "$(command -v apt-get)" ]; then
        use_sudo apt-get update --allow-releaseinfo-change
        use_sudo apt-get -y install \
            sudo bzip2 gawk curl patch \
            build-essential make autotools-dev automake autoconf \
            texlive texinfo
    elif [ -x "$(command -v brew)" ]; then
        brew install autoconf automake libtool texinfo

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
            sudo wget curl unzip build-base make bash
    elif [ -x "$(command -v pacman)" ]; then
        packages+=(
            git msys2-keyring base-devel make autoconf automake1.16 automake-wrapper
        )

        if [ -n "${MINGW_PACKAGE_PREFIX:-}" ]; then
            packages+=(
                "$MINGW_PACKAGE_PREFIX-make" "$MINGW_PACKAGE_PREFIX-binutils"
            )
        fi

        pacman -S --quiet --noconfirm --needed "${packages[@]}"
    fi
}

function install_system_dependencies() {
    packages=("$@")

    if [ -x "$(command -v apt-get)" ]; then
        use_sudo apt-get update
        use_sudo apt-get -y install \
            sudo bzip2 gawk curl libssl-dev patch \
            build-essential make autotools-dev automake autoconf \
            cpanminus \
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
            sudo wget curl unzip xclip \
            build-base gcc g++ make musl-dev openssl-dev zlib-dev \
            perl-dev perl-utils perl-app-cpanminus \
            bash openssl "${packages[@]}"
    elif [ -x "$(command -v pacman)" ]; then
        packages+=(
            git msys2-keyring msys2-runtime-devel msys2-w32api-headers msys2-w32api-runtime
            base-devel gcc make autoconf automake1.16 automake-wrapper
            libtool libcrypt-devel openssl openssl-devel
            perl-devel
        )

        if [ -n "${MINGW_PACKAGE_PREFIX:-}" ]; then
            packages+=(
                "$MINGW_PACKAGE_PREFIX-make" "$MINGW_PACKAGE_PREFIX-gcc" "$MINGW_PACKAGE_PREFIX-binutils"
                "$MINGW_PACKAGE_PREFIX-openssl"
            )
        fi

        pacman -S --quiet --noconfirm --needed "${packages[@]}"
    fi
}

function install_perl_dependencies() {
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
        pl2bat "$(which pl2bat)" 2>/dev/null || true
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
            install_perl_modules App::cpanminus || true
        fi
    fi

    # We intentionally install as little as possible here to support as many system combinations as
    # possible including MSYS, cygwin, Ubuntu, Alpine, etc. The more libraries we add here the more
    # seemingly obscure issues you could run into e.g., missing 'cc1' or 'poll.h' even when they are
    # in fact installed.
    modules=(
        Carp Test::Output Module::Build IO::Scalar Devel::Cover::Report::Coveralls
        Test::More Test::Exception
    )

    if [ -n "${MSYSTEM:-}" ]; then
        modules+=(ExtUtils::PL2Bat Inline::C Win32::Mutex)
    fi

    install_perl_modules "${modules[@]}"

    echo "Installed required Perl dependencies."
}

function install_dependencies() {
    update_stow_environment

    install_system_dependencies "$@"
    install_perl_dependencies
}

function install_texlive() {
    if [ -x "$(command -v apt-get)" ]; then
        install_system_dependencies texlive texinfo
    elif [ -x "$(command -v pacman)" ]; then
        packages+=(texinfo texinfo-tex)

        if [ -n "${MINGW_PACKAGE_PREFIX:-}" ]; then
            packages+=(
                "$MINGW_PACKAGE_PREFIX-texlive-bin" "$MINGW_PACKAGE_PREFIX-texlive-core"
                "$MINGW_PACKAGE_PREFIX-texlive-extra-utils"
                "$MINGW_PACKAGE_PREFIX-poppler"
            )
        fi

        install_system_dependencies "${packages[@]}"
    fi
}

function make_docs() {
    STOW_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && cd ../ && pwd -P)"

    # shellcheck source=tools/stow-lib.sh
    source "$STOW_ROOT/tools/stow-lib.sh"

    update_stow_environment

    # Install 'TeX Live' so that we have 'tex' and the related
    # tools needed to generate documentation.
    install_texlive

    siteprefix=
    eval "$(perl -V:siteprefix)"

    if [ -x "$(command -v cygpath)" ]; then
        siteprefix=$(cygpath "$siteprefix")
    fi

    echo "Site prefix: $siteprefix"

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
        TEXINPUTS="../;." run_build_command pdftex "./stow.texi"
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
        run_build_command "$TEXI2DVI" \
            --pdf --language=texinfo \
            --expand --batch \
            --verbose \
            -I "." -I "$STOW_ROOT" -I "$STOW_ROOT/doc" -I "$STOW_ROOT/doc/manual.t2d/pdf/src" \
            -o "$STOW_ROOT/doc/manual.pdf" \
            "./stow.texi"
    )
}

update_stow_environment
