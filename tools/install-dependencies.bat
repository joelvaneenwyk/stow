@echo off

setlocal EnableExtensions EnableDelayedExpansion

perl "%~dp0initialize-cpan-config.pl"

call :InstallDependencies "%~dp0..\"
exit /b

:InstallDependencies
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%

    :: Already installed as part of Strawberry Perl but install/update regardless.
    call cpanm --version > nul 2>&1
    if errorlevel 1 (
        call cpan -i -T App::cpanminus > nul 2>&1
    )

    ::
    :: Install dependencies. Note that 'Inline::C' requires 'make' and 'gcc' to be installed. It
    :: is recommended to install the following MSYS2 packages:
    ::
    ::      - mingw-w64-x86_64-make
    ::      - mingw-w64-x86_64-gcc
    ::      - mingw-w64-x86_64-binutils
    ::
    set STARTING_DIR=%CD%
    cd /d "%STOW_ROOT%"
    call cpanm --installdeps --notest .
    cd /d "%STARTING_DIR%"
exit /b
