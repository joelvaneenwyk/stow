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

call :RunStowTests "%~dp0..\"
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

:RunStowTests
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%
    call "%STOW_ROOT%\tools\stow-environment.bat"

    call :Run prove -I "%STOW_ROOT_UNIX%/t/" -I "%STOW_ROOT_UNIX%/bin/" -I "%STOW_ROOT_UNIX%/lib/" --timer --formatter "TAP::Formatter::JUnit" "%STOW_ROOT_UNIX%/t/"
endlocal & exit /b
