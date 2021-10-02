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

call :StartShell "%~dp0"

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

:StartShell
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set _cd=%CD%

    set STOW_ROOT=%_root:~0,-1%
    set STOW_ROOT_UX=%STOW_ROOT:\=/%
    set STOW_VERSION_TEXI=%STOW_ROOT%\doc\version.texi

    set STOW_PERL=perl
    set STOW_BUILD_TOOLS_ROOT=%STOW_ROOT%\.tmp
    if not exist "%STOW_BUILD_TOOLS_ROOT%" mkdir "%STOW_BUILD_TOOLS_ROOT%"

    set TMPDIR=%STOW_ROOT%\.tmp\temp
    if not exist "%TMPDIR%" mkdir "%TMPDIR%"

    set WIN_UNIX_DIR=%STOW_BUILD_TOOLS_ROOT%\msys64
    set WIN_UNIX_DIR_UX=%WIN_UNIX_DIR:\=/%

    set PERL_INCLUDE_UX=-I %WIN_UNIX_DIR_UX%/usr/share/automake-1.16 -I %WIN_UNIX_DIR_UX%/share/autoconf
    set PERL=perl %PERL_INCLUDE_UX%

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
    %STOW_PERL% -e "print 'Perl v' . substr($^V, 1) . ""\n"""
    if errorlevel 1 (
        echo Perl executable invalid or missing: '%STOW_PERL%'
        exit /b 1
    )

    if not exist "%BASH_EXE%" goto:$ValidatePerlShebang
    for /f "tokens=*" %%a in ('"%BASH% "command -v perl""') do set "STOW_PERL_PATH=%%a"
    :$ValidatePerlShebang
    if "!STOW_PERL_PATH!"=="" set STOW_PERL_PATH=/bin/perl
    echo Perl: !STOW_PERL_PATH!

    :: Get Stow version number
    for /f "tokens=*" %%a in ('"%STOW_PERL% "%STOW_ROOT%\tools\get-version""') do set "STOW_VERSION=%%a"
    echo Stow v!STOW_VERSION!

    if not exist "%WIN_UNIX_DIR%\post-install.bat" goto:$SkipPostInstall
        cd /d "%WIN_UNIX_DIR%"
        call :Run "%WIN_UNIX_DIR%\post-install.bat"
        echo Executed post install script.

    :$SkipPostInstall

    set PATH_ORIGINAL=

    ::set PATH=%WIN_UNIX_DIR%\usr\bin;%WIN_UNIX_DIR%\bin;%STOW_BUILD_TOOLS_ROOT%\texlive\bin\win32;%WIN_UNIX_DIR%\usr\bin\core_perl;%WIN_UNIX_DIR%\mingw32\bin
    ::set PATH=

    ::set MSYSTEM=MINGW64
    ::set MSYS2_NOSTART=yes
    ::set MSYS2_PATH_TYPE=inherit
    ::set MSYS=winsymlinks:nativestrict
    ::%BASH_EXE% --noprofile --norc

    ::call %WIN_UNIX_DIR%\msys2_shell.cmd -no-start -mingw64 -defterm -shell bash -here --noprofile --rcfile "/etc/profile"
    call %WIN_UNIX_DIR%\msys2_shell.cmd -no-start -mingw64 -defterm -shell bash -here
exit /b
