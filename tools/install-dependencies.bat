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
echo call :RunCommand powershell -NoLogo -NoProfile -File "%~dp0install-dependencies.ps1"

call :InstallPerlDependencies "%~dp0..\"

exit /b

:InstallPerlDependencies
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    call "%_root:~0,-1%\tools\stow-environment.bat" --refresh

    echo ::group::Initialize CPAN
    (
        echo yes && echo. && echo no && echo exit
    ) | "%STOW_PERL%" -I "%STOW_PERL_LOCAL_LIB%" -MCPAN -e "shell"
    echo ::endgroup::

    call :RunTaskGroup "%STOW_PERL%" -I "%STOW_PERL_LOCAL_LIB%" "%~dp0initialize-cpan-config.pl"

    :: First install 'cpanminus' and 'local::lib' before installing remaining libraries
    call :InstallPerlModules ^
        "YAML" "ExtUtils::MakeMaker" "ExtUtils::Config" ^
        "App::cpanminus" ^
        "local::lib"

    :: Install dependencies. Note that 'Inline::C' requires 'make' and 'gcc' to be installed. It
    :: is recommended to install MSYS2 packages for copmiling (e.g. mingw-w64-x86_64-make) but
    :: many/most Perl distributions already come with the required tools for compiling.
    call :InstallPerlModules ^
        "Carp" "Module::Build" "IO::Scalar" ^
        "Devel::Cover::Report::Coveralls" ^
        "Test::Output" "Test::More" "Test::Exception" ^
        "ExtUtils::PL2Bat" "Inline::C" "Win32::Mutex" ^
        "TAP::Formatter::JUnit"
    goto:$InstallDone

    :$InstallDone
    cd /d "%STARTING_DIR%"
exit /b

:RunTaskGroup
    for /F "tokens=*" %%i in ('echo %*') do set _cmd=%%i
    echo ::group::%_cmd%
    echo [command]%_cmd%
    %*
    echo ::endgroup::
exit /b

:RunCommand
    for /F "tokens=*" %%i in ('echo %*') do set _cmd=%%i
    echo [command]%_cmd%
    %*
exit /b

:InstallPerlModules
    cd /d "!STOW_ROOT!"

    set _cmd_base="%STOW_PERL%" -I "%STOW_PERL_LOCAL_LIB%" -MCPAN

    "%STOW_PERL%" -MApp::cpanminus::fatscript -le 1 > nul 2>&1
    if "!ERRORLEVEL!"=="0" goto:$UseCpanm

    :$Install
        set _module=%~1
        shift
        if "%_module%"=="" goto:$Done

        set _cmd=!_cmd_base!

        "%STOW_PERL%" -Mlocal::lib -le 1 > nul 2>&1
        if "!ERRORLEVEL!"=="0" set _cmd=!_cmd! -Mlocal::lib="%STOW_PERL_LOCAL_LIB%"

        set _cmd=!_cmd_base! -e "CPAN::Shell->notest('install', '!_module!')"
        echo ::group::Install '!_module!'
        echo [command]!_cmd!
        !_cmd!
        echo ::endgroup::
        if not "!ERRORLEVEL!"=="0" exit /b !ERRORLEVEL!
        goto:$Install

    :$UseCpanm
        set _modules=
        :$GetModulesLoop
            set _modules=!_modules! %~1
            shift
            if not "%~1"=="" goto:$GetModulesLoop

        "%STOW_PERL%" -Mlocal::lib -le 1 > nul 2>&1
        if "!ERRORLEVEL!"=="0" set _cmd_base=!_cmd_base! -Mlocal::lib="%STOW_PERL_LOCAL_LIB%"

        set _cmd=!_cmd_base! -MApp::cpanminus::fatscript -le
        set _cmd=!_cmd! "my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;" --
        set _cmd=!_cmd! --skip-installed --skip-satisfied --local-lib "%STOW_PERL_LOCAL_LIB%" --notest
        set _cmd=!_cmd! !_modules!

        echo ::group::Install Module(s)
        echo [command]!_cmd!
        !_cmd!
        echo ::endgroup::
    :$Done
exit /b
