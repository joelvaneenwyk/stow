@echo off

setlocal EnableExtensions EnableDelayedExpansion

echo ##[cmd] perl "%~dp0initialize-cpan-config.pl"
perl "%~dp0initialize-cpan-config.pl"

call :InstallDependencies "%~dp0..\"
exit /b

:InstallDependencies
    setlocal EnableExtensions EnableDelayedExpansion

    set _starting_directory=%CD%
    set _root=%~dp1

    if "%STOW_ROOT%"=="" set STOW_ROOT=%_root:~0,-1%
    if "%STOW_PERL%"=="" set STOW_PERL=perl

    :: Already installed as part of Strawberry Perl but install/update regardless.
    call cpanm --version > nul 2>&1
    if errorlevel 1 (
        !STOW_PERL! -MCPAN -e "install App::cpanminus"
    )

    ::
    :: Install dependencies. Note that 'Inline::C' requires 'make' and 'gcc' to be installed. It
    :: is recommended to install the following MSYS2 packages but many Perl distributions already
    :: come with the required tools for compiling.
    ::
    ::      - mingw-w64-x86_64-make
    ::      - mingw-w64-x86_64-gcc
    ::      - mingw-w64-x86_64-binutils
    ::
    cd /d "!STOW_ROOT!"
    echo ##[cmd] !STOW_PERL! -MApp::cpanminus::fatscript -le "my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;" -- --installdeps --notest .
    !STOW_PERL! -MApp::cpanminus::fatscript -le "my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;" -- --installdeps --notest .
    cd /d "%_starting_directory%"
exit /b
