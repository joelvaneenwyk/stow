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

call :MakeStow "%~dp0..\"

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

:MakeStow
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set _cd=%CD%
    set STOW_ROOT=%_root:~0,-1%
    call "%STOW_ROOT%\tools\stow-environment.bat"

    :: Generate documentation using 'bash' and associated unix tools which
    :: are required due to reliance on autoconf.
    call :MakeDocs

    set USE_LIB_PMDIR=
    set PMDIR=%STOW_ROOT%\lib
    set PMDIR=%PMDIR:\=/%

    set _inc=0
    for /f "tokens=*" %%a in ('%STOW_PERL% -V') do (
        if "!_inc!"=="1" (
            echo %%a | findstr /C:"%PMDIR%" > nul 2>&1

            if not errorlevel 1 (
                set PERL5LIB=%%a
                echo Target folder '!PMDIR!' is part of built-in @INC, so everything
                echo should work fine with no extra include statements.
                goto:$PerlModuleCheckDone
            )
        )
        if "%%a"=="@INC:" (
            set _inc=1
        )
    )
    :$PerlModuleCheckDone

    if not "!PERL5LIB!"=="" goto:$InitializedPerlModuleDir
        set USE_LIB_PMDIR=use lib "%PMDIR%";
        set PERL5LIB=!PMDIR!
        echo Target folder is not part of built-in @INC, so the
        echo front-end scripts will add an appropriate "use lib" line
        echo to compensate.
        echo ----------------------------------------
        echo PERL5LIB: '!PERL5LIB!'
    :$InitializedPerlModuleDir

    call :ReplaceVariables "%STOW_ROOT%\bin\chkstow"
    call :ReplaceVariables "%STOW_ROOT%\bin\stow"
    call :ReplaceVariables "%STOW_ROOT%\lib\Stow\Util.pm"

    call :ReplaceVariables "%STOW_ROOT%\lib\Stow.pm"
    type "%STOW_ROOT%\default-ignore-list" >> "%STOW_ROOT%\lib\Stow.pm"

    call pod2man --name stow --section 8 "%STOW_ROOT%\bin\stow" > "%STOW_ROOT%\doc\stow.8"

    cd /d "%STOW_ROOT%"

    :: Exeute 'Build.PL' to generate build scripts: 'Build' and 'Build.bat'
    call :Run %STOW_PERL% -I "%STOW_ROOT%\lib" -I "%STOW_ROOT%\bin" "%STOW_ROOT%\Build.PL"

    :: Remove all intermediate files before running Stow for the first time
    rmdir /q /s "%STOW_ROOT%\_Inline\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\bin\_Inline\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\tools\_Inline\" > nul 2>&1

    :: Make sure that 'stow' was successfully compiled by printing out the version.
    call :Run %STOW_PERL% -I "%STOW_ROOT%\lib" "%STOW_ROOT%\bin\stow" --version

    :$MakeEnd
        :: Remove leftover files so that 'Build distcheck' succeeds
        del "%STOW_ROOT%\doc\stow.log" > nul 2>&1
        del "%STOW_ROOT%\doc\texput.log" > nul 2>&1
        rmdir /q /s "%STOW_ROOT%\doc\manual.t2d\" > nul 2>&1
        rmdir /q /s "%STOW_ROOT%\_Inline\" > nul 2>&1
        rmdir /q /s "%STOW_ROOT%\bin\_Inline\" > nul 2>&1
        rmdir /q /s "%STOW_ROOT%\tools\_Inline\" > nul 2>&1

        :: Restore original directory
        cd /d "%_cd%"
endlocal & exit /b

:ReplaceVariables
    setlocal EnableExtensions EnableDelayedExpansion

    set input_file=%~1.in
    set output_file=%~1

    :: This is more explicit and reliable than the config file trick
    set perl_command=%STOW_PERL% -p
    set perl_command=!perl_command! -e "s/\@PERL\@/$ENV{STOW_PERL_UNIX}/g;"
    set perl_command=!perl_command! -e "s/\@VERSION\@/$ENV{STOW_VERSION}/g;"
    set perl_command=!perl_command! -e "s/\@USE_LIB_PMDIR\@/$ENV{USE_LIB_PMDIR}/g;"
    set perl_command=!perl_command! "%input_file%"

    if "%GITHUB_ACTIONS%"=="" (
        echo ##[cmd] !perl_command!
    ) else (
        echo [command]!perl_command!
    )
    call !perl_command! >"%output_file%"
    echo Generated output: '%output_file%'
endlocal & exit /b

:MakeDocs
    setlocal EnableExtensions EnableDelayedExpansion

    if not exist "%WIN_UNIX_DIR%\usr\bin\bash.exe" (
        echo ERROR: Failed to find unix tools. Please install dependencies first.
        exit /b 5
    )

    call :CreateStowInfo "%~dp0..\"

    cd /d "%STOW_ROOT%"

    set "MSYSTEM=MSYS"
    set "MSYS2_PATH_TYPE=inherit"
    set "PERL=%STOW_PERL_UNIX%"
    set "STOW_PERL=%STOW_PERL_UNIX%"
    set "PATH=%PERL_BIN_C_DIR%;%WIN_UNIX_DIR%\usr\bin;%WIN_UNIX_DIR%\bin;%STOW_BUILD_TOOLS_ROOT%\texlive\bin\win32;%WIN_UNIX_DIR%\usr\bin\core_perl;%WIN_UNIX_DIR%\mingw32\bin"

    call :Run %BASH% "source ./tools/stow-environment.sh && install_packages"
    call :Run %BASH% "source ./tools/stow-environment.sh && make_docs"
    call :Run %BASH% "autoreconf --install --verbose"
    call :Run %BASH% "./configure --prefix='' --with-pmdir='%PERL5LIB%'"
    call :Run %BASH% "make doc/manual.pdf"
    call :Run %BASH% "make bin/stow bin/chkstow lib/Stow.pm lib/Stow/Util.pm"
    call :Run %BASH% "make doc/manual-single.html"
exit /b

:CreateStowInfo
    setlocal EnableExtensions EnableDelayedExpansion

    set STOW_VERSION_TEXI=%STOW_ROOT%\doc\version.texi
    echo @set UPDATED 0 0 0 >"%STOW_VERSION_TEXI%"
    echo @set UPDATED-MONTH ${2:-0} ${3:-0} >>"%STOW_VERSION_TEXI%"
    echo @set EDITION !STOW_VERSION! >>"%STOW_VERSION_TEXI%"
    echo @set VERSION !STOW_VERSION! >>"%STOW_VERSION_TEXI%"

    set PERL_INCLUDE=-I %WIN_UNIX_DIR_UNIX%/usr/share/automake-1.16
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UNIX%/usr/share/autoconf
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UNIX%/usr/share/texinfo
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UNIX%/usr/share/texinfo/lib/libintl-perl/lib
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UNIX%/usr/share/texinfo/lib/Text-Unidecode/lib
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UNIX%/usr/share/texinfo/lib/Unicode-EastAsianWidth/lib

    :: Use 'stow.texi' to generate 'stow.info'
    cd "%STOW_ROOT%"
    call :Run "%WIN_UNIX_DIR%\usr\bin\perl" %PERL_INCLUDE% "%WIN_UNIX_DIR%\usr\bin\texi2any" -I doc\ -o doc\ doc\stow.texi
    echo Generated 'doc\stow.info'
exit /b 0
