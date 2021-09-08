@echo off

setlocal EnableExtensions EnableDelayedExpansion

perl "%~dp0initialize-cpan-config.pl"

call :InstallDependencies "%~dp0..\"
exit /b

:InstallDependencies
    setlocal EnableExtensions EnableDelayedExpansion

    set STARTING_DIR=%CD%
    set STOW_ROOT=%~dp1

    :: Already installed as part of Strawberry Perl but install/update regardless.
    call cpan -i -T App::cpanminus

    ::
    :: Install dependencies. Note that 'Inline::C' requires 'make' and 'gcc' to be installed. It
    :: is recommended to install the following MSYS2 packages:
    ::
    ::      - mingw-w64-x86_64-make
    ::      - mingw-w64-x86_64-gcc
    ::      - mingw-w64-x86_64-binutils
    ::
    cd /d "%STOW_ROOT%"
    call cpanm --installdeps --notest .
    cd /d "%STARTING_DIR%"
exit /b 0
