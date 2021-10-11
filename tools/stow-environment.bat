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

if not exist "%STOW_ROOT%" goto:$Setup
if "%~1"=="--refresh" goto:$Setup
exit /b 0

:$Setup
call :SetupStowEnvironment "%~dp0..\"
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

:SetupStowEnvironment
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STARTING_DIR=%CD%
    set STOW_ROOT=%_root:~0,-1%
    set STOW_ROOT_UNIX=%STOW_ROOT:\=/%
    set STOW_VERSION=0.0.0

    set STOW_LOCAL_BUILD_ROOT=%STOW_ROOT%\.tmp
    if not exist "%STOW_LOCAL_BUILD_ROOT%" mkdir "%STOW_LOCAL_BUILD_ROOT%"

    set TMPDIR=%STOW_LOCAL_BUILD_ROOT%\temp
    if not exist "%TMPDIR%" mkdir "%TMPDIR%"

    set WIN_UNIX_DIR=%STOW_LOCAL_BUILD_ROOT%\msys64
    if exist "!WIN_UNIX_DIR!" goto:$FoundUnixTools
    "C:\Windows\System32\WHERE.exe" /Q msys2_shell
    if not "!ERRORLEVEL!"=="0" goto:$FoundUnixTools
        for /f "tokens=* usebackq" %%a in (`"C:\Windows\System32\WHERE.exe" msys2_shell`) do (
            set WIN_UNIX_DIR=%%a
            goto:$FixUnixToolPath
        )
        :$FixUnixToolPath
        if not exist "!WIN_UNIX_DIR!" set WIN_UNIX_DIR=
        if "!WIN_UNIX_DIR!"=="" goto:$FoundUnixTools
        for %%F in ("!WIN_UNIX_DIR!") do set WIN_UNIX_DIR=%%~dpF
        set WIN_UNIX_DIR=!WIN_UNIX_DIR:~0,-1!

    :$FoundUnixTools
    if not exist "!WIN_UNIX_DIR!" set WIN_UNIX_DIR=
    set WIN_UNIX_DIR_UNIX=
    if exist "!WIN_UNIX_DIR!" set WIN_UNIX_DIR_UNIX=!WIN_UNIX_DIR:\=/!

    set GUILE_LOAD_PATH=!WIN_UNIX_DIR!\usr\share\guile\2.0
    set GUILE_LOAD_COMPILED_PATH=!WIN_UNIX_DIR!\usr\lib\guile\2.0\ccache

    set PATH_ORIGINAL=%PATH%

    set TEX_DIR=%STOW_LOCAL_BUILD_ROOT%\texlive\bin\win32
    set TEX=%TEX_DIR%\tex.exe

    set STOW_HOME=%STOW_LOCAL_BUILD_ROOT%\home
    if not exist "%STOW_HOME%" mkdir "%STOW_HOME%"

    set BASH_EXE=!WIN_UNIX_DIR!\usr\bin\bash.exe
    set BASH="%BASH_EXE%" --noprofile --norc -c

    if exist "!STOW_PERL!" goto:$PerlValidate

    :: Print Perl version number
    "C:\Windows\System32\WHERE.exe" /Q perl
    if not !ERRORLEVEL!==0 goto:$PerlValidate
    for /f "tokens=* usebackq" %%a in (`"C:\Windows\System32\WHERE.exe" perl`) do (
        set "STOW_PERL=%%a"
        goto:$PerlValidate
    )
    :$PerlValidate

    for /f "tokens=* usebackq" %%a in (`%STOW_PERL% -e "print substr($^V, 1)"`) do (
        set "STOW_PERL_VERSION=%%a"
    )
    if errorlevel 1 (
        echo ERROR: Perl executable invalid or missing: '!STOW_PERL!'
        goto:$InitializeEnvironment
    )

    set STOW_PERL_LOCAL_LIB=!STOW_LOCAL_BUILD_ROOT!\perllib\windows\%STOW_PERL_VERSION%
    if not exist "!STOW_LOCAL_BUILD_ROOT!\perllib" mkdir "!STOW_LOCAL_BUILD_ROOT!\perllib"
    if not exist "!STOW_PERL_LOCAL_LIB!" mkdir "!STOW_PERL_LOCAL_LIB!"
    set STOW_PERL_LOCAL_LIB_UNIX=!STOW_PERL_LOCAL_LIB:\=/!

    set PERL5LIB=!STOW_PERL_LOCAL_LIB_UNIX!/lib

    set PERL_LOCAL_LIB_ROOT=%STOW_PERL_LOCAL_LIB_UNIX%

    set STOW_PERL_ARGS=-I"!STOW_PERL_LOCAL_LIB_UNIX!"
    set STOW_PERL_INIT=!STOW_PERL_LOCAL_LIB!\init.bat

    if exist "!STOW_PERL_INIT!" del "!STOW_PERL_INIT!"
    "%STOW_PERL%" -Mlocal::lib -le 1 > nul 2>&1
    if "!ERRORLEVEL!"=="0" (
        set STOW_PERL_ARGS=!STOW_PERL_ARGS! -Mlocal::lib="!STOW_PERL_LOCAL_LIB_UNIX!"
        "!STOW_PERL!" !STOW_PERL_ARGS! >"!STOW_PERL_INIT!"
    )

    if exist "!STOW_PERL_INIT!" echo Generated local lib script: '!STOW_PERL_INIT!'
    if exist "!STOW_PERL_INIT!" call "!STOW_PERL_INIT!"

    for %%F in ("!STOW_PERL!") do set PERL_BIN_DIR=%%~dpF
    if exist "!PERL_BIN_DIR!" set PERL_BIN_DIR=%PERL_BIN_DIR:~0,-1%

    for %%F in ("!PERL_BIN_DIR!\..\site\bin\cover.bat") do set PERL_SITE_BIN_DIR=%%~dpF
    if not exist "!PERL_SITE_BIN_DIR!" set PERL_SITE_BIN_DIR=
    if exist "!PERL_SITE_BIN_DIR!" set PERL_SITE_BIN_DIR=%PERL_SITE_BIN_DIR:~0,-1%

    for %%F in ("!PERL_BIN_DIR!\..\..\c\bin\gmake.exe") do set PERL_BIN_C_DIR=%%~dpF
    if not exist "!PERL_BIN_C_DIR!" set PERL_BIN_C_DIR=
    if exist "!PERL_BIN_C_DIR!" set PERL_BIN_C_DIR=%PERL_BIN_C_DIR:~0,-1%

    if not exist "%BASH_EXE%" goto:$ValidatePerlShebang
        call :GetCygPath "!STOW_PERL!" "STOW_PERL_UNIX"

        if not "!STOW_PERL_UNIX!"=="" goto:$ValidatePerlShebang
        for /f "tokens=*" %%a in ('"%BASH% "command -v perl""') do (
            set "STOW_PERL_UNIX=%%a"
        )
    :$ValidatePerlShebang
    if "!STOW_PERL_UNIX!"=="" set STOW_PERL_UNIX=/bin/perl

    echo ##[cmd] !STOW_PERL! !STOW_PERL_ARGS! -MCPAN -e "use Config; print $Config{privlib};"
    for /f %%a in ('!STOW_PERL! !STOW_PERL_ARGS! -MCPAN -e "use Config; print $Config{privlib};"') do (
        set "PERL_LIB=%%a"
    )
    if not exist "%PERL_LIB%" exit /b 2
    set PERL_CPAN_CONFIG=%PERL_LIB%\CPAN\Config.pm

    echo ##[cmd] !STOW_PERL! !STOW_PERL_ARGS! "%STOW_ROOT%\tools\get-version"
    :: Get Stow version number
    for /f "tokens=*" %%a in ('"!STOW_PERL! !STOW_PERL_ARGS! "%STOW_ROOT%\tools\get-version""') do (
        set "STOW_VERSION=%%a"
    )

    call :GetCygPath "!STOW_ROOT!" "STOW_ROOT_MSYS"

    :$InitializeEnvironment
        echo ------------------
        echo Perl v%STOW_PERL_VERSION%
        echo Perl: '!STOW_PERL!'
        echo Perl Bin: '!PERL_BIN_DIR!'
        echo Perl C Bin: '!PERL_BIN_C_DIR!'
        echo Perl (MSYS): '!STOW_PERL_UNIX!'
        echo Perl CPAN Config: '%PERL_CPAN_CONFIG%'
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
    endlocal & (
        set "STOW_ROOT=%STOW_ROOT%"
        set "STOW_ROOT_UNIX=%STOW_ROOT_UNIX%"
        set "STOW_LOCAL_BUILD_ROOT=%STOW_LOCAL_BUILD_ROOT%"
        set "STOW_VERSION=%STOW_VERSION%"
        set "STOW_PERL=%STOW_PERL%"
        set "STOW_PERL_UNIX=%STOW_PERL_UNIX%"
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

    call "%STOW_PERL_LOCAL_LIB%\init.bat"

    if not exist "%STOW_PERL%" (
        echo ERROR: Perl not found.
        exit /b 55
    )
exit /b 0

:GetCygPath
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
