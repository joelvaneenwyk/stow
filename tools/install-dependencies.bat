@echo off
::
:: This file is part of GNU Stow.
::
:: GNU Stow is free software: you can redistribute it and/or modify it
:: under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.
::
:: GNU Stow is distributed in the hope that it will be useful, but
:: WITHOUT ANY WARRANTY; without even the implied warranty of
:: MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
:: General Public License for more details.
::
:: You should have received a copy of the GNU General Public License
:: along with this program. If not, see https://www.gnu.org/licenses/.
::

setlocal EnableExtensions EnableDelayedExpansion

call :RunCommand powershell -NoLogo -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -scope CurrentUser;"
call :RunCommand powershell -NoLogo -NoProfile -File "%~dp0install-dependencies.ps1"

call :InstallPerlDependencies "%~dp0..\"

exit /b

:InstallPerlDependencies
    setlocal EnableExtensions EnableDelayedExpansion

    set _starting_directory=%CD%
    set _root=%~dp1

    if "%STOW_ROOT%"=="" set STOW_ROOT=%_root:~0,-1%
    if "%STOW_PERL%"=="" set STOW_PERL=perl

    (
        echo yes && echo. && echo no && echo exit
    ) | "%STOW_PERL%" -MCPAN -e "shell"

    call :RunTaskGroup !STOW_PERL! "%~dp0initialize-cpan-config.pl"

    :: Already installed as part of Strawberry Perl but install/update regardless.
    !STOW_PERL! -MApp::cpanminus::fatscript -le 1 > nul 2>&1
    if not "!ERRORLEVEL!"=="0" (
        call :RunTaskGroup !STOW_PERL! -MCPAN -e "install App::cpanminus"
    )

    :: Install dependencies. Note that 'Inline::C' requires 'make' and 'gcc' to be installed. It
    :: is recommended to install MSYS2 packages for copmiling (e.g. mingw-w64-x86_64-make) but
    :: many/most Perl distributions already come with the required tools for compiling.
    cd /d "!STOW_ROOT!"
    !STOW_PERL! -MApp::cpanminus::fatscript -le 1 > nul 2>&1
    if "!ERRORLEVEL!"=="0" goto:$UseCpanm
    call :InstallPerlModules ^
        Carp  Module::Build IO::Scalar ^
        Devel::Cover::Report::Coveralls ^
        Test::Output Test::More Test::Exception ^
        ExtUtils::PL2Bat Inline::C Win32::Mutex
    goto:$InstallDone

    :$UseCpanm
    call :RunTaskGroup !STOW_PERL! ^
        -MApp::cpanminus::fatscript -le ^
        "my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;" -- ^
        --installdeps --notest .

    :$InstallDone
    cd /d "%_starting_directory%"
exit /b

:RunTaskGroup
    set _cmd=%*
    echo ::group::%_cmd%
    echo [command]%_cmd%
    %_cmd%
    echo ::endgroup::
exit /b

:RunCommand
    set _cmd=%*
    echo [command]%_cmd%
    %_cmd%
exit /b

:InstallPerlModules
    :$Install
        set _module=%~1
        shift
        if "%_module%"=="" exit /b
        call :RunTaskGroup !STOW_PERL! -MCPAN -e "CPAN::Shell->notest('install', '%_module%')"
    goto:$Install
exit /b
