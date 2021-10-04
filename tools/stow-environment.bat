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

    set STOW_BUILD_TOOLS_ROOT=%STOW_ROOT%\.tmp
    if not exist "%STOW_BUILD_TOOLS_ROOT%" mkdir "%STOW_BUILD_TOOLS_ROOT%"

    set TMPDIR=%STOW_ROOT%\.tmp\temp
    if not exist "%TMPDIR%" mkdir "%TMPDIR%"

    set WIN_UNIX_DIR=%STOW_BUILD_TOOLS_ROOT%\msys64
    if exist "!WIN_UNIX_DIR!" goto:$FoundUnixTools
    "C:\Windows\System32\WHERE.exe" /Q msys2_shell
    if not !ERRORLEVEL!==0 goto:$FoundUnixTools
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

    set TEX=%STOW_BUILD_TOOLS_ROOT%\texlive\bin\win32\tex.exe

    set STOW_HOME=%STOW_BUILD_TOOLS_ROOT%\home
    if not exist "%STOW_HOME%" mkdir "%STOW_HOME%"

    set BASH_EXE=!WIN_UNIX_DIR!\usr\bin\bash.exe
    set BASH="%BASH_EXE%" --noprofile --norc -c

    :: Print Perl version number
    "C:\Windows\System32\WHERE.exe" /Q perl
    if not !ERRORLEVEL!==0 goto:$PerlValidate
    for /f "tokens=* usebackq" %%a in (`"C:\Windows\System32\WHERE.exe" perl`) do (
        set "STOW_PERL=%%a"
        goto:$PerlValidate
    )
    :$PerlValidate
    if not exist "!STOW_PERL!" set STOW_PERL=perl
    "!STOW_PERL!" -e "print 'Perl v' . substr($^V, 1) . ""\n"""
    if errorlevel 1 (
        echo ERROR: Perl executable invalid or missing: '!STOW_PERL!'
        goto:$InitializeEnvironment
    )

    for %%F in ("!STOW_PERL!") do set PERL_BIN_DIR=%%~dpF
    for %%F in ("!PERL_BIN_DIR!\..\..\c\bin\gmake.exe") do set PERL_BIN_C_DIR=%%~dpF
    if not exist "!PERL_BIN_C_DIR!" set PERL_BIN_C_DIR=

    if not exist "%BASH_EXE%" goto:$ValidatePerlShebang
        for /f "tokens=*" %%a in ('""!WIN_UNIX_DIR!\usr\bin\cygpath.exe" "!STOW_PERL!""') do (
            set "STOW_PERL_UNIX=%%a"
        )

        if not "!STOW_PERL_UNIX!"=="" goto:$ValidatePerlShebang
        for /f "tokens=*" %%a in ('"%BASH% "command -v perl""') do (
            set "STOW_PERL_UNIX=%%a"
        )
    :$ValidatePerlShebang
    if "!STOW_PERL_UNIX!"=="" set STOW_PERL_UNIX=/bin/perl

    for /f %%a in ('!STOW_PERL! -MCPAN -e "use Config; print $Config{privlib};"') do (
        set "PERL_LIB=%%a"
    )
    set PERL_CPAN_CONFIG=%PERL_LIB%\CPAN\Config.pm

    :: Get Stow version number
    for /f "tokens=*" %%a in ('"!STOW_PERL! "%STOW_ROOT%\tools\get-version""') do (
        set "STOW_VERSION=%%a"
    )

    ::call :GetCygpath "!STOW_ROOT!" "STOW_ROOT_MSYS"
    ::set PERL5LIB=!STOW_ROOT_MSYS!/lib;/usr/share/automake-1.16;/share/autoconf

    set PERL_INCLUDE_UNIX=-I %WIN_UNIX_DIR_UNIX%/usr/share/automake-1.16 -I %WIN_UNIX_DIR_UNIX%/share/autoconf

    :$InitializeEnvironment
        echo Perl: '!STOW_PERL!'
        echo Perl Bin: '!PERL_BIN_DIR!'
        echo Perl C Bin: '!PERL_BIN_C_DIR!'
        echo Perl (MSYS): '!STOW_PERL_UNIX!'
        echo Perl CPAN Config: '%PERL_CPAN_CONFIG%'
        echo Stow Root (MSYS): '!STOW_ROOT_MSYS!'
        echo MSYS2: '!WIN_UNIX_DIR_UNIX!'
        echo Stow v!STOW_VERSION!

    if not exist "!WIN_UNIX_DIR!\post-install.bat" goto:$SkipPostInstall
        cd /d "!WIN_UNIX_DIR!"
        call :Run "!WIN_UNIX_DIR!\post-install.bat"
        echo Executed post install script.

    :$SkipPostInstall
    echo ----------------------------------------
    endlocal & (
        set "STOW_ROOT=%STOW_ROOT%"
        set "STOW_ROOT_UNIX=%STOW_ROOT_UNIX%"
        set "STOW_BUILD_TOOLS_ROOT=%STOW_BUILD_TOOLS_ROOT%"
        set "STOW_VERSION=%STOW_VERSION%"
        set "STOW_PERL=%STOW_PERL%"
        set "STOW_PERL_UNIX=%STOW_PERL_UNIX%"
        set "PERL_BIN_C_DIR=%PERL_BIN_C_DIR%"
        set "PERL_LIB=%PERL_LIB%"
        set "PERL_CPAN_CONFIG=%PERL_CPAN_CONFIG%"
        set "PERL_INCLUDE_UNIX=%PERL_INCLUDE_UNIX%"
        set "PERL5LIB=%PERL5LIB%"
        set "STOW_HOME=%STOW_HOME%"
        set "STARTING_DIR=%STARTING_DIR%"
        set "BASH=%BASH%"
        set "BASH_EXE=%BASH_EXE%"
        set "TMPDIR=%TMPDIR%"
        set "WIN_UNIX_DIR=%WIN_UNIX_DIR%"
        set "GUILE_LOAD_PATH=%GUILE_LOAD_PATH%"
        set "GUILE_LOAD_COMPILED_PATH=%GUILE_LOAD_COMPILED_PATH%"
        set "TEX=%TEX%"
    )

    if not exist "%STOW_PERL%" exit /b 55
exit /b 0

:GetCygpath
    setlocal EnableDelayedExpansion
        set _inPath=%~1
        set _outPath=
        set _outVar=%~2
        set _cygpath="%WIN_UNIX_DIR%\usr\bin\cygpath.exe"
        if not exist "%_cygpath%" goto:$Done
        echo ""%WIN_UNIX_DIR%\usr\bin\cygpath.exe" "%_inPath%""
        for /f "tokens=* usebackq" %%a in (`""%WIN_UNIX_DIR%\usr\bin\cygpath.exe" "%_inPath%""`) do (
            set "_outPath=%%a"
        )
        :$Done
    endlocal & (
        set "%~2=%_outPath%"
    )
exit /b
