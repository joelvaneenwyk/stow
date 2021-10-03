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

    set STOW_BUILD_TOOLS_ROOT=%STOW_ROOT%\.tmp
    if not exist "%STOW_BUILD_TOOLS_ROOT%" mkdir "%STOW_BUILD_TOOLS_ROOT%"

    set TMPDIR=%STOW_ROOT%\.tmp\temp
    if not exist "%TMPDIR%" mkdir "%TMPDIR%"

    set WIN_UNIX_DIR=%STOW_BUILD_TOOLS_ROOT%\msys64
    set WIN_UNIX_DIR_UNIX=%WIN_UNIX_DIR:\=/%

    set PERL_INCLUDE_UNIX=-I %WIN_UNIX_DIR_UNIX%/usr/share/automake-1.16 -I %WIN_UNIX_DIR_UNIX%/share/autoconf

    set SHELL=%WIN_UNIX_DIR%\bin\sh.exe

    set GUILE_LOAD_PATH=%WIN_UNIX_DIR%\usr\share\guile\2.0
    set GUILE_LOAD_COMPILED_PATH=%WIN_UNIX_DIR%\usr\lib\guile\2.0\ccache

    set PATH_ORIGINAL=%PATH%

    set TEX=%STOW_BUILD_TOOLS_ROOT%\texlive\bin\win32\tex.exe

    set HOME=%STOW_BUILD_TOOLS_ROOT%\home
    if not exist "%HOME%" mkdir "%HOME%"

    set BASH_EXE=%WIN_UNIX_DIR%\usr\bin\bash.exe
    set BASH="%BASH_EXE%" --noprofile --norc -c

    :: Print Perl version number
    for /f "tokens=*" %%a in ('where perl') do (
        set "STOW_PERL=%%a"
        goto:$PerlValidate
    )
    :$PerlValidate
    if "!STOW_PERL!"=="" set STOW_PERL=perl
    "!STOW_PERL!" -e "print 'Perl v' . substr($^V, 1) . ""\n"""
    if errorlevel 1 (
        echo Perl executable invalid or missing: '!STOW_PERL!'
        exit /b 1
    )

    if not exist "%BASH_EXE%" goto:$ValidatePerlShebang
    for /f "tokens=*" %%a in ('""%WIN_UNIX_DIR%\usr\bin\cygpath.exe" "!STOW_PERL!""') do (
        set "STOW_PERL_UNIX=%%a"
    )

    if not "!STOW_PERL_UNIX!"=="" goto:$ValidatePerlShebang
    for /f "tokens=*" %%a in ('"%BASH% "command -v perl""') do (
        set "STOW_PERL_UNIX=%%a"
    )
    :$ValidatePerlShebang
    if "!STOW_PERL_UNIX!"=="" set STOW_PERL_UNIX=/bin/perl

    echo Perl: '!STOW_PERL!'
    echo Perl (MSYS2): '!STOW_PERL_UNIX!'

    for /f %%a in ('!STOW_PERL! -MCPAN -e "use Config; print $Config{privlib};"') do (
        set "PERL_LIB=%%a"
    )
    set PERL_CPAN_CONFIG=%PERL_LIB%\CPAN\Config.pm
    echo CPAN Config: '%PERL_CPAN_CONFIG%'

    :: Get Stow version number
    for /f "tokens=*" %%a in ('"!STOW_PERL! "%STOW_ROOT%\tools\get-version""') do set "STOW_VERSION=%%a"
    echo Stow v!STOW_VERSION!

    if not exist "%WIN_UNIX_DIR%\post-install.bat" goto:$SkipPostInstall
        cd /d "%WIN_UNIX_DIR%"
        call :Run "%WIN_UNIX_DIR%\post-install.bat"
        echo Executed post install script.

    :$SkipPostInstall
    endlocal & (
        set "STOW_ROOT=%STOW_ROOT%"
        set "STOW_ROOT_UNIX=%STOW_ROOT_UNIX%"
        set "STOW_BUILD_TOOLS_ROOT=%STOW_BUILD_TOOLS_ROOT%"
        set "STOW_VERSION=%STOW_VERSION%"
        set "STOW_PERL=%STOW_PERL%"
        set "STOW_PERL_UNIX=%STOW_PERL_UNIX%"
        set "PERL_INCLUDE_UNIX=%PERL_INCLUDE_UNIX%"
        set "PERL_LIB=%PERL_LIB%"
        set "PERL_CPAN_CONFIG=%PERL_CPAN_CONFIG%"
        set "HOME=%HOME%"
        set "STARTING_DIR=%STARTING_DIR%"
        set "SHELL=%SHELL%"
        set "BASH=%BASH%"
        set "BASH_EXE=%BASH_EXE%"
        set "TMPDIR=%TMPDIR%"
        set "WIN_UNIX_DIR=%WIN_UNIX_DIR%"
        set "GUILE_LOAD_PATH=%GUILE_LOAD_PATH%"
        set "GUILE_LOAD_COMPILED_PATH=%GUILE_LOAD_COMPILED_PATH%"
        set "TEX=%TEX%"
    )
exit /b
