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

call :StartShell "%~dp0" %*

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
exit /b

:StartShell
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set _stow_root=%_root:~0,-1%

    set _args=
    shift
    :$ArgumentParse
        set "_args=!_args! %1"
        shift
    if not "%~1"=="" goto:$ArgumentParse

    call "%_stow_root%\tools\stow-environment.bat"

    :: Remove all intermediate files before we start
    call "%_stow_root%\tools\make-clean.bat"

    :: We use 'minimal' to match what CI uses by default to ensure we have a clean environment
    :: for reproducing issues on CI. You can enable 'inherit' if needed but it tends to just make
    :: debugging more difficult as you get potential binary overlaps.
    set "MSYS2_PATH_TYPE=minimal"

    :: No need to update PATH when using 'minimal' so this is just here for when you want to enable
    :: the 'inherit' mode.
    set "PATH=%TEX_DIR%;%PERL_BIN_DIR%;%PERL_BIN_C_DIR%;%PATH%"

    set "STOW_PERL=%STOW_PERL_UNIX%"
    set "HOME=%STOW_HOME%"

    if not exist "%WIN_UNIX_DIR%\msys2_shell.cmd" (
        echo ERROR: Failed to find MSYS2 installation.
        exit /b 5
    )

    call :Run wsl bash test.sh
    if not "!ERRORLEVEL!"=="0" (
        echo ERROR: WSL doc build failed.
        exit /b 1
    )

    call :Run "%WIN_UNIX_DIR%\msys2_shell.cmd" -no-start -mingw64 -defterm -shell bash -here -c "./test.sh!_args!"
exit /b
