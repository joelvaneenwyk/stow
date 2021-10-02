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

call :InstallTexLive "%~dp0..\"

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
    !STOW_PERL! -MApp::cpanminus::fatscript -le 1 > nul 2>&1
    if "!ERRORLEVEL!"=="0" goto:$UseCpanm
    call :InstallPerlModules Carp Test::Output Module::Build IO::Scalar Devel::Cover::Report::Coveralls Test::More Test::Exception ExtUtils::PL2Bat Inline::C Win32::Mutex
    goto:$InstallDone

    :$UseCpanm
    call :RunTaskGroup !STOW_PERL! -MApp::cpanminus::fatscript -le "my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;" -- --installdeps --notest .

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

:InstallTexLive
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%
    set BUILD_TEMP_ROOT=%STOW_ROOT%\.tmp

    set TEXLIVE_ROOT=%BUILD_TEMP_ROOT%\texlive-install
    set TEXLIVE_INSTALL=%TEXLIVE_ROOT%\install-tl-windows.bat

    set TEXDIR=%BUILD_TEMP_ROOT%\texlive
    set TEXLIVE_BIN=%TEXDIR%\bin\win32
    set TEXMFCONFIG=%TEXDIR%\texmf-config
    set TEXMFHOME=%TEXDIR%\texmf-local
    set TEXMFLOCAL=%TEXDIR%\texmf-local
    set TEXMFSYSCONFIG=%TEXDIR%\texmf-config
    set TEXMFSYSVAR=%TEXDIR%\texmf-var
    set TEXMFVAR=%TEXDIR%\texmf-var

    set TEXLIVE_INSTALL_PREFIX=%TEXDIR%
    set TEXLIVE_INSTALL_TEXDIR=%TEXDIR%
    set TEXLIVE_INSTALL_TEXMFCONFIG=%TEXDIR%\texmf-config
    set TEXLIVE_INSTALL_TEXMFHOME=%TEXDIR%\texmf-local
    set TEXLIVE_INSTALL_TEXMFLOCAL=%TEXDIR%\texmf-local
    set TEXLIVE_INSTALL_TEXMFSYSCONFIG=%TEXDIR%\texmf-config
    set TEXLIVE_INSTALL_TEXMFSYSVAR=%TEXDIR%\texmf-var
    set TEXLIVE_INSTALL_TEXMFVAR=%TEXDIR%\texmf-var

    if not exist "%TEXLIVE_BIN%\tex.exe" goto:$InstallTexLive
        echo Skipped install. Tex executable already exists: '%TEXLIVE_BIN%\tex.exe'
        exit /b 0

    :$InstallTexLive
        call :RunTaskGroup call "%TEXLIVE_INSTALL%" -no-gui -portable -profile "%STOW_ROOT%\tools\install-texlive.profile"
exit /b
