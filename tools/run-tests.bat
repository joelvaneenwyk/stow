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

:RunStowTests
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    call "%_root:~0,-1%\tools\stow-environment.bat"
    if not "!ERRORLEVEL!"=="0" exit /b

    set _result_filename=%STOW_ROOT%\test_results_windows.xml

    if "%GITHUB_ENV%"=="" goto:$SkipGitHubActionSetup
        echo STOW_TEST_RESULTS=%_result_filename% >>"%GITHUB_ENV%"
        echo STOW_CPAN_LOGS=%USERPROFILE%\.cpan*\work\**\*.log >>"%GITHUB_ENV%"

    :$SkipGitHubActionSetup
    del "%STOW_ROOT%\Build" > nul 2>&1
    del "%STOW_ROOT%\Build.bat" > nul 2>&1
    del "%STOW_ROOT%\config.*" > nul 2>&1
    del "%STOW_ROOT%\configure" > nul 2>&1
    del "%STOW_ROOT%\configure~" > nul 2>&1
    del "%STOW_ROOT%\configure.lineno" > nul 2>&1
    del "%STOW_ROOT%\Makefile" > nul 2>&1
    del "%STOW_ROOT%\Makefile.in" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\tmp-testing-trees\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\cover_db\" > nul 2>&1
    mkdir "%STOW_ROOT%\cover_db\"

    set _cmd="%STOW_PERL%" %STOW_PERL_ARGS% -MApp::Prove
    set _cmd=!_cmd! -le "my $c = App::Prove->new; $c->process_args(@ARGV); $c->run" --
    set _cmd=!_cmd! --formatter "TAP::Formatter::JUnit"
    set _cmd=!_cmd! --norc --timer --verbose --normalize --parse
    set _cmd=!_cmd! -I "!STOW_PERL_LOCAL_LIB_UNIX!/lib/perl5"
    set _cmd=!_cmd! -I "%STOW_ROOT_UNIX%/t/"
    set _cmd=!_cmd! -I "%STOW_ROOT_UNIX%/bin/"
    set _cmd=!_cmd! -I "%STOW_ROOT_UNIX%/lib/"
    set _cmd=!_cmd! "%STOW_ROOT_UNIX%/t/"
    if "%GITHUB_ACTIONS%"=="" (
        echo ##[cmd] !_cmd!
    ) else (
        echo [command]!_cmd!
    )
    cd /d "%STOW_ROOT%"
    call !_cmd! >"%_result_filename%"
    echo Test results: '%_result_filename%'
    if not "!ERRORLEVEL!"=="0" (
        echo Tests failed with error code: '!ERRORLEVEL!'
        endlocal & exit /b !ERRORLEVEL!
    )

    call :RunCover
endlocal & exit /b

:RunCover
    setlocal EnableExtensions EnableDelayedExpansion

    set _cover=%STOW_PERL_LOCAL_LIB%\bin\cover
    if not exist "!_cover!" set _cover=%PERL_SITE_BIN_DIR%\cover
    if not exist "!_cover!" (
        echo [WARNING] Cover tool not found: '!_cover!'
        endlocal & exit /b 44
    )

    set PERL5OPT=
    set PERL_LOCAL_LIB_ROOT=
    set PERL_MB_OPT=
    set PERL_MM_OPT=
    set PERL5LIB=
    set HARNESS_PERL_SWITCHES=%STOW_PERL_ARGS% -I "%STOW_PERL_LOCAL_LIB_UNIX%/lib/perl5" -I "%STOW_ROOT_UNIX%/t/" -I "%STOW_ROOT_UNIX%/lib/" -I "%STOW_ROOT_UNIX%/bin/" -MDevel::Cover

    cd /d "%STOW_ROOT%"
    set _cmd="%STOW_PERL%" -I "%STOW_PERL_LOCAL_LIB_UNIX%/lib/perl5" -MApp::Prove
    set _cmd=!_cmd! -le "my $c = App::Prove->new; $c->process_args(@ARGV); $c->run;" --
    set _cmd=!_cmd! --lib -I "%STOW_ROOT_UNIX%/t/" -I "%STOW_ROOT_UNIX%/lib/" -I "%STOW_ROOT_UNIX%/bin/"
    set _cmd=!_cmd! --norc --timer --normalize
    set _cmd=!_cmd! "%STOW_ROOT_UNIX%/t/"
    call :Run !_cmd!
    if not "!ERRORLEVEL!"=="0" (
        echo [ERROR] Cover failed with error code: '!ERRORLEVEL!'
        endlocal & exit /b !ERRORLEVEL!
    )

    cd /d "%STOW_ROOT%"
    set _cmd="%STOW_PERL%" %STOW_PERL_ARGS%
    set _cmd=!_cmd! "!_cover!"
    if "%GITHUB_ENV%"=="" (
        set _cmd=!_cmd! -report html
    ) else (
        set _cmd=!_cmd! -report coveralls
    )
    call :Run !_cmd!
    if not "!ERRORLEVEL!"=="0" (
        echo [ERROR] Cover report generation failed with error code: '!ERRORLEVEL!'
        endlocal & exit /b !ERRORLEVEL!
    )
endlocal & exit /b

:Run %*=Command with arguments
    if "%GITHUB_ACTIONS%"=="" (
        echo ##[cmd] %*
    ) else (
        echo [command]%*
    )
    call %*
endlocal & exit /b
