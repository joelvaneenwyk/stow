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
    call "%_root:~0,-1%\tools\stow-environment.bat"

    set _cmd="%PERL_BIN_DIR%\prove.bat"
    set _cmd=!_cmd! -I "%STOW_ROOT_UNIX%/t/" -I
    set _cmd=!_cmd! -I "%STOW_ROOT_UNIX%/bin/" -I
    set _cmd=!_cmd! -I "%STOW_ROOT_UNIX%/lib/" -I
    set _cmd=!_cmd! --verbose --timer --normalize --formatter "TAP::Formatter::JUnit"
    set _cmd=!_cmd! "%STOW_ROOT_UNIX%/t/"

    if "%GITHUB_ACTIONS%"=="" (
        echo ##[cmd] !_cmd!
    ) else (
        echo [command]!_cmd!
    )

    set _result_filename=%STOW_ROOT%\test_results_windows.xml
    call !_cmd! >"%_result_filename%"

    if not "%GITHUB_ENV%"=="" (
        echo "STOW_TEST_RESULTS=%_result_filename%" >>%GITHUB_ENV%
        echo "STOW_CPAN_LOGS=%USER_PROFILE%\.cpan*\work\**\*.log" >>%GITHUB_ENV%
    )

    echo Test results: '%_result_filename%'
    if not "!ERRORLEVEL!"=="0" (
        echo Tests failed with error code: '!ERRORLEVEL!'
    )
endlocal & exit /b
