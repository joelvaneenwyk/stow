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

    rmdir /q /s "%USERPROFILE%\.cpan\CPAN" > nul 2>&1
    rmdir /q /s "%USERPROFILE%\.cpan\prefs" > nul 2>&1
    rmdir /q /s "%USERPROFILE%\.cpan-w64\CPAN" > nul 2>&1
    rmdir /q /s "%USERPROFILE%\.cpan-w64\prefs" > nul 2>&1

    set _root=%~dp1
    call "%_root:~0,-1%\tools\stow-environment.bat" --refresh
    if not "!ERRORLEVEL!"=="0" exit /b !ERRORLEVEL!

    echo ::group::Initialize CPAN
    (
        echo yes && echo. && echo no && echo exit
    ) | "%STOW_PERL%" -I "%STOW_PERL_LOCAL_LIB_UNIX%" -MCPAN -e "shell"
    echo ::endgroup::

    call :RunTaskGroup "%STOW_PERL%" -I "%STOW_PERL_LOCAL_LIB_UNIX%" "%~dp0initialize-cpan-config.pl"

    :: First install 'cpanminus' and 'local::lib' before installing remaining libraries
    call :InstallPerlModules ^
        "YAML" "ExtUtils::MakeMaker" "ExtUtils::Config" ^
        "App::cpanminus" ^
        "local::lib"
    if not "!ERRORLEVEL!"=="0" exit /b !ERRORLEVEL!

    :: Install dependencies. Note that 'Inline::C' requires 'make' and 'gcc' to be installed. It
    :: is recommended to install MSYS2 packages for copmiling (e.g. mingw-w64-x86_64-make) but
    :: many/most Perl distributions already come with the required tools for compiling.
    call :InstallPerlModules ^
        "YAML" "ExtUtils::Config" ^
        "LWP::Protocol::https" "IO::Socket::SSL" "Net::SSLeay" ^
        "Carp" "Module::Build" "Module::Build::Tiny" "IO::Scalar" ^
        "Devel::Cover" "Devel::Cover::Report::Coveralls" ^
        "Test::Harness" "Test::Output" "Test::More" "Test::Exception" ^
        "ExtUtils::PL2Bat" "Inline::C" "Win32::Mutex" ^
        "TAP::Formatter::JUnit"

    if not "!ERRORLEVEL!"=="0" exit /b !ERRORLEVEL!

    :$InstallDone
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

    set _cmd_base="%STOW_PERL%" -I "%STOW_PERL_LOCAL_LIB_UNIX%" -MCPAN
    set _cmd_return=0

    "%STOW_PERL%" -MApp::cpanminus::fatscript -le 1 > nul 2>&1
    if "!ERRORLEVEL!"=="0" goto:$UseCpanm

    :: Since we call CPAN manually it is not always set, but there are some libraries
    :: like IO::Socket::SSL use this to determine whether or not to prompt for next
    :: steps e.g., see https://github.com/gbarr/perl-libnet/blob/master/Makefile.PL
    set PERL5_CPAN_IS_RUNNING=1
    set NO_NETWORK_TESTING=n

    :$Install
        set _module=%~1
        shift
        if "%_module%"=="" goto:$Done

        set _cmd=!_cmd_base!

        "%STOW_PERL%" -Mlocal::lib -le 1 > nul 2>&1
        if "!ERRORLEVEL!"=="0" set _cmd=!_cmd! -Mlocal::lib="%STOW_PERL_LOCAL_LIB_UNIX%"

        set _cmd=!_cmd_base! -e "CPAN::Shell->notest('install', '!_module!')"
        echo ::group::Install '!_module!'
        echo [command]!_cmd!
        !_cmd!
        set _cmd_return=!ERRORLEVEL!
        echo ::endgroup::
        if not "!_cmd_return!"=="0" goto:$Done
        goto:$Install

    :$UseCpanm
        set _modules=
        :$GetModulesLoop
            set _modules=!_modules! %~1
            shift
            if not "%~1"=="" goto:$GetModulesLoop

        "%STOW_PERL%" -Mlocal::lib -le 1 > nul 2>&1
        if "!ERRORLEVEL!"=="0" set _cmd_base=!_cmd_base! -Mlocal::lib="%STOW_PERL_LOCAL_LIB_UNIX%"

        set _cmd=!_cmd_base! -MApp::cpanminus::fatscript -le
        set _cmd=!_cmd! "my $c = App::cpanminus::script->new; $c->parse_options(@ARGV); $c->doit;" --
        set _cmd=!_cmd! --skip-installed --skip-satisfied --local-lib "%STOW_PERL_LOCAL_LIB_UNIX%" --notest
        set _cmd=!_cmd! !_modules!

        echo ::group::Install Module(s)
        echo [command]!_cmd!
        !_cmd!
        set _cmd_return=!ERRORLEVEL!
        echo ::endgroup::
    :$Done
    set PERL5_CPAN_IS_RUNNING=
exit /b !_cmd_return!
