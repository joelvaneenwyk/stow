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

call :SetupStowEnvironment "%~dp0..\" %*
exit /b

::
:: Local functions
::

:Run %*=Command with arguments
    if "%GITHUB_ACTIONS%"=="" (
        echo ##[cmd] %*
    ) else (
        echo [command]%*
    )
    call %*
endlocal & exit /b

:RunTaskGroup
    for /F "tokens=*" %%i in ('echo %*') do set _cmd=%%i
    echo ::group::%_cmd%
    echo [command]%_cmd%
    %*
    echo ::endgroup::
exit /b

:FindTool
    setlocal EnableExtensions EnableDelayedExpansion
        set _output_variable=%~1
        set _file=%~2
        set _output=!%_output_variable%!
        set _where=C:\Windows\System32\WHERE.exe
        if exist "!_output!" goto:$FindToolDone

        "%_where%" /Q %_file%
        if not "!ERRORLEVEL!"=="0" goto:$FindToolDone
            for /f "tokens=* usebackq" %%a in (`"%_where%" %_file%`) do (
                set _output=%%a
                goto:$FindToolDone
            )

        :$FindToolDone
        if not exist "!_output!" set _output=
    endlocal & (
        set "%_output_variable%=%_output%"
    )
exit /b

:SetupStowEnvironment
    setlocal EnableExtensions EnableDelayedExpansion

        set _root=%~dp1
        if not exist "%STOW_ROOT%" goto:$Setup
        if "%~2"=="" goto:$Setup
        if "%~2"=="--refresh" goto:$Setup
        goto:$EnvironmentSetupDone

        :$Setup
        set STARTING_DIR=%CD%
        set STOW_ROOT=%_root:~0,-1%
        set STOW_ROOT_UNIX=!STOW_ROOT:\=/!
        set STOW_VERSION=0.0.0

        set STOW_LOCAL_BUILD_ROOT=!STOW_ROOT!\.tmp
        if not exist "!STOW_LOCAL_BUILD_ROOT!" mkdir "!STOW_LOCAL_BUILD_ROOT!"

        set PATH_ORIGINAL=%PATH%

        set TMPDIR=%STOW_LOCAL_BUILD_ROOT%\temp
        if not exist "%TMPDIR%" mkdir "%TMPDIR%"

        set WIN_UNIX_DIR=!STOW_LOCAL_BUILD_ROOT!\msys64\msys2_shell.cmd
        call :FindTool "WIN_UNIX_DIR" "msys2_shell"
        call :GetDirectoryPath "WIN_UNIX_DIR" "!WIN_UNIX_DIR!"

        set WIN_UNIX_DIR_UNIX=
        if exist "!WIN_UNIX_DIR!" set WIN_UNIX_DIR_UNIX=!WIN_UNIX_DIR:\=/!

        set TEX_DIR=%STOW_LOCAL_BUILD_ROOT%\texlive\bin\win32
        set TEX=%TEX_DIR%\tex.exe

        set STOW_HOME=%STOW_LOCAL_BUILD_ROOT%\home
        if not exist "%STOW_HOME%" mkdir "%STOW_HOME%"

        set BASH_EXE=!WIN_UNIX_DIR!\usr\bin\bash.exe
        set BASH="%BASH_EXE%" --noprofile --norc -c

        call :FindTool "STOW_PERL" "perl"
        call :StorePerlOutput "STOW_PERL_VERSION" -e "print substr($^^V, 1)"
        if not "!ERRORLEVEL!"=="0" (
            echo ERROR: Perl executable invalid or missing: '!STOW_PERL!'
            goto:$InitializeEnvironment
        )

        set STOW_PERL_LOCAL_LIB=!STOW_LOCAL_BUILD_ROOT!\perllib\windows\%STOW_PERL_VERSION%
        if not exist "!STOW_LOCAL_BUILD_ROOT!\perllib" mkdir "!STOW_LOCAL_BUILD_ROOT!\perllib"
        if not exist "!STOW_PERL_LOCAL_LIB!" mkdir "!STOW_PERL_LOCAL_LIB!"
        set STOW_PERL_LOCAL_LIB_UNIX=!STOW_PERL_LOCAL_LIB:\=/!

        set PERL5LIB=!STOW_PERL_LOCAL_LIB_UNIX!/lib
        set PERL_LOCAL_LIB_ROOT=%STOW_PERL_LOCAL_LIB_UNIX%
        set STOW_PERL_ARGS=-I "!STOW_PERL_LOCAL_LIB_UNIX!/lib/perl5"

        set STOW_PERL_INIT=!STOW_PERL_LOCAL_LIB!\init.bat
        if exist "!STOW_PERL_INIT!" del "!STOW_PERL_INIT!"
        "!STOW_PERL!" !STOW_PERL_ARGS! -Mlocal::lib -le 1 > nul 2>&1
        if "!ERRORLEVEL!"=="0" (
            set "STOW_PERL_ARGS=%STOW_PERL_ARGS% -Mlocal::lib^="!STOW_PERL_LOCAL_LIB_UNIX!""
            "!STOW_PERL!" !STOW_PERL_ARGS! >"!STOW_PERL_INIT!"
        )

        call :GetDirectoryPath "PERL_BIN_DIR" "!STOW_PERL!"
        call :GetDirectoryPath "STOW_PERL_ROOT" "!PERL_BIN_DIR!\..\..\DISTRIBUTIONS.txt"

        set PERL_SITE_BIN_DIR=!STOW_PERL_ROOT!\perl\site\bin
        set PERL_BIN_C_DIR=!STOW_PERL_ROOT!\c\bin

        call :ConvertToCygwinPath "!STOW_PERL!" "STOW_PERL_UNIX"
        if "!STOW_PERL_UNIX!"=="" (
            call :StoreCommandOutput "STOW_PERL_UNIX" %BASH% "command -v perl"4
        )
        if "!STOW_PERL_UNIX!"=="" set STOW_PERL_UNIX=/bin/perl

        echo ::group::Initialize CPAN
        (
            echo yes && echo. && echo no && echo exit
        ) | "!STOW_PERL!" %STOW_PERL_ARGS% -MCPAN -e "shell"
        echo ::endgroup::

        call :ConvertToCygwinPath "!STOW_ROOT!" "STOW_ROOT_MSYS"
        call :StorePerlOutput "STOW_VERSION" "%STOW_ROOT%\tools\get-version"
        call :RunTaskGroup "!STOW_PERL!" %STOW_PERL_ARGS% "%STOW_ROOT%\tools\initialize-cpan-config.pl"

        call :StorePerlOutput "PERL_LIB" -MCPAN -e "use Config; print $Config{privlib};"
        if exist "!PERL_LIB!" (
            set "PERL_CPAN_CONFIG=%PERL_LIB%\CPAN\Config.pm"
        )

        :$InitializeEnvironment
            echo ------------------
            echo Perl v%STOW_PERL_VERSION%
            echo Perl: '!STOW_PERL!'
            echo Perl Bin: '!PERL_BIN_DIR!'
            echo Perl C Bin: '!PERL_BIN_C_DIR!'
            echo Perl (MSYS): '!STOW_PERL_UNIX!'
            echo Perl CPAN Config: '%PERL_CPAN_CONFIG%'
            if exist "!STOW_PERL_INIT!" echo Perl Init: '!STOW_PERL_INIT!'
            echo MSYS2: '!WIN_UNIX_DIR!'
            echo MSYS2 (unixy): '!WIN_UNIX_DIR_UNIX!'
            echo Stow Root (unixy): '!STOW_ROOT_MSYS!'
            echo Stow v!STOW_VERSION!

        if not exist "!WIN_UNIX_DIR!\post-install.bat" goto:$SkipPostInstall
            cd /d "!WIN_UNIX_DIR!"
            call :Run "!WIN_UNIX_DIR!\post-install.bat"
            echo Executed post install script.

        :$SkipPostInstall
        echo ------------------

        :$EnvironmentSetupDone
        if exist "%STOW_PERL_INIT%" call "%STOW_PERL_INIT%"

        :: Convert to forward slash otherwise it fails on older versions of Perl e.g, 5.14
        set PERL_MB_OPT=%PERL_MB_OPT:\=/%
        set PERL_MM_OPT=%PERL_MM_OPT:\=/%
        set PERL5LIB=%PERL5LIB:\=/%
    endlocal & (
        set "PATH=%PATH%"
        set "PERL5LIB=%PERL5LIB%"
        set "PERL_LOCAL_LIB_ROOT=%PERL_LOCAL_LIB_ROOT%"
        set "PERL_MB_OPT=%PERL_MB_OPT%"
        set "PERL_MM_OPT=%PERL_MM_OPT%"
        set "STOW_ROOT=%STOW_ROOT%"
        set "STOW_ROOT_UNIX=%STOW_ROOT_UNIX%"
        set "STOW_LOCAL_BUILD_ROOT=%STOW_LOCAL_BUILD_ROOT%"
        set "STOW_VERSION=%STOW_VERSION%"
        set "STOW_PERL=%STOW_PERL%"
        set "STOW_PERL_INIT=%STOW_PERL_INIT%"
        set "STOW_PERL_UNIX=%STOW_PERL_UNIX%"
        set "STOW_PERL_ARGS=%STOW_PERL_ARGS%"
        set "STOW_PERL_LOCAL_LIB=%STOW_PERL_LOCAL_LIB%"
        set "STOW_PERL_LOCAL_LIB_UNIX=%STOW_PERL_LOCAL_LIB_UNIX%"
        set "PERL_BIN_DIR=%PERL_BIN_DIR%"
        set "PERL_BIN_C_DIR=%PERL_BIN_C_DIR%"
        set "PERL_SITE_BIN_DIR=%PERL_SITE_BIN_DIR%"
        set "PERL_LIB=%PERL_LIB%"
        set "PERL_CPAN_CONFIG=%PERL_CPAN_CONFIG%"
        set "PERL5LIB=%PERL5LIB%"
        set "STOW_HOME=%STOW_HOME%"
        set "STARTING_DIR=%STARTING_DIR%"
        set "BASH=%BASH%"
        set "BASH_EXE=%BASH_EXE%"
        set "TMPDIR=%TMPDIR%"
        set "WIN_UNIX_DIR=%WIN_UNIX_DIR%"
        set "GUILE_LOAD_PATH=%GUILE_LOAD_PATH%"
        set "GUILE_LOAD_COMPILED_PATH=%GUILE_LOAD_COMPILED_PATH%"
        set "TEX_DIR=%TEX_DIR%"
        set "TEX=%TEX%"
    )

    if not exist "%STOW_PERL%" (
        echo [ERROR] Perl not found.
        exit /b 55
    )
exit /b 0

:GetDirectoryPath
    setlocal EnableDelayedExpansion
        set _output=
        set _output_variable=%~1
        set _input_path=%~2

        if not exist "!_input_path!" goto:$DirectoryResolved
            for %%F in ("%_input_path%") do set _output=%%~dpF
            if not exist "!_output!" set _output=
            if exist "!_output!" set _output=%_output:~0,-1%

        :$DirectoryResolved
    endlocal & (
        set "%_output_variable%=%_output%"
    )
exit /b

:StorePerlOutput
    setlocal EnableDelayedExpansion
        set _output=
        set _output_variable=%~1
        shift

        set "_args=%1"
        shift
        :$GetPerlArgs
            if "%~1"=="" goto:$ExecutePerlCommand
            set "_args=%_args% %1"
            shift
        goto:$GetPerlArgs
        :$ExecutePerlCommand

        set "_cmd=%STOW_PERL% -I "!STOW_PERL_LOCAL_LIB_UNIX!/lib/perl5" -Mlocal::lib^="%STOW_PERL_LOCAL_LIB_UNIX%""
        echo ##[perl] !_cmd! %_args%
        for /f "tokens=* usebackq" %%a in (`!_cmd! %_args%`) do (
            set "_output=%%a"
            goto:$PerlCommandDone
        )

        :$PerlCommandDone
    endlocal & (
        set "%_output_variable%=%_output%"
    )
exit /b

:StoreCommandOutput
    setlocal EnableDelayedExpansion
        set _output_variable=%~1
        shift

        set _args=
        set "_args=%1"
        shift
        :$GetArgs
            if "%~1"=="" goto:$ExecuteCommand
            set "_args=%_args% %1"
            shift
        goto:$GetArgs
        :$ExecuteCommand

        echo ##[cmd] %_args%
        for /f "tokens=* usebackq" %%a in (`%_args%`) do (
            set "_output=%%a"
            goto:$CommandDone
        )

        :$CommandDone
    endlocal & (
        set "%_output_variable%=%_output%"
    )
exit /b

:ConvertToCygwinPath
    setlocal EnableDelayedExpansion
        set _inPath=%~1
        set _outVar=%~2
        set _outPath=
        set _cygpath="%WIN_UNIX_DIR%\usr\bin\cygpath.exe"
        if not exist "%_cygpath%" goto:$Done
        for /f "tokens=* usebackq" %%a in (`""%WIN_UNIX_DIR%\usr\bin\cygpath.exe" "%_inPath%""`) do (
            set "_outPath=%%a"
        )
        :$Done
    endlocal & (
        set "%_outVar%=%_outPath%"
    )
exit /b
