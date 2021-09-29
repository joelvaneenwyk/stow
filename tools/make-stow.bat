@echo off

call "%~dp0make-clean.bat"

call :MakeStow "%~dp0..\"
exit /b

:MakeStow
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%
    set STOW_PERL=perl
    set TMPDIR=%STOW_ROOT%\.tmp
    set EZWINPORTS_ROOT=%STOW_ROOT%\.tmp\ezwinports
    set UNIX_ROOT=%EZWINPORTS_ROOT:\=/%

    set USE_LIB_PMDIR=

    set SHELL_BIN=%EZWINPORTS_ROOT%\bin\sh

    set PERL5LIB=%UNIX_ROOT%/share/automake-1.11:%UNIX_ROOT%/share/autoconf
    set PERL5LIB=%PERL5LIB:\=/%

    set PERL5INC=-I %UNIX_ROOT%/share/automake-1.11 -I %UNIX_ROOT%/share/autoconf
    set PERL_BIN=perl %PERL5INC%

    set PMDIR=%STOW_ROOT%\lib
    set PMDIR=%PMDIR:\=/%

    set PATH=%EZWINPORTS_ROOT%\bin;%EZWINPORTS_ROOT%\mingw32\bin;%PATH%

    set SHELL=%UNIX_ROOT%/bin/sh
    set AUTORECONF=%PERL_BIN% %UNIX_ROOT%/bin/autoreconf
    set AUTOCONF=%SHELL_BIN% %UNIX_ROOT%/bin/autoconf
    set AUTOHEADER=%PERL_BIN% %UNIX_ROOT%/bin/autoheader
    set AUTOM4TE=%PERL_BIN% %UNIX_ROOT%/bin/autom4te
    set AUTOMAKE=%PERL_BIN% %UNIX_ROOT%/bin/automake
    set ACLOCAL=%PERL_BIN% %UNIX_ROOT%/bin/aclocal
    set LIBTOOLIZE=libtoolize
    set AUTOPOINT=autopoint
    set MAKE=make

    set autom4te_perllibdir=%UNIX_ROOT%/share/autoconf
    set perllibdir=%UNIX_ROOT%/share/aclocal-1.11
    set ACLOCAL_PATH=%UNIX_ROOT%/share/aclocal-1.11

    for /f %%a in ('%STOW_PERL% %STOW_ROOT%\tools\get-version') do set "STOW_VERSION=%%a"

    echo Stow v!STOW_VERSION!
    %STOW_PERL% -e "print 'Perl v' . substr($^V, 1) . ""\n"""
    if errorlevel 1 (
        echo Perl executable invalid or missing: '%STOW_PERL%'
        exit /b 1
    )

    set _inc=0
    for /f "tokens=*" %%a in ('%STOW_PERL% -V') do (
        if "!_inc!"=="1" (
            echo %%a | findstr /C:"%PMDIR%" 1>nul

            if not errorlevel 1 (
                set PERL5LIB=%%a
                echo Target folder '!PERL5LIB!' is part of built-in @INC, so everything
                echo should work fine with no extra effort.
                goto:$PMCheckDone
            )
        )
        if "%%a"=="@INC:" (
            set _inc=1
        )
    )
    :$PMCheckDone

    if "!PERL5LIB!"=="" (
        set USE_LIB_PMDIR=use lib "%PMDIR%";
        set PERL5LIB=%PMDIR%
        echo Target folder is not part of built-in @INC, so the
        echo front-end scripts will add an appropriate "use lib" line
        echo to compensate.
    )

    echo.
    echo PERL5LIB: '!PERL5LIB!'

    if not exist "%STOW_ROOT%\doc" mkdir "%STOW_ROOT%\doc"

    call :ReplaceVariables "%STOW_ROOT%\bin\chkstow"
    call :ReplaceVariables "%STOW_ROOT%\bin\stow"
    call :ReplaceVariables "%STOW_ROOT%\lib\Stow\Util.pm"

    call :ReplaceVariables "%STOW_ROOT%\lib\Stow.pm"
    type "%STOW_ROOT%\default-ignore-list" >> "%STOW_ROOT%\lib\Stow.pm"

    call pod2man --name stow --section 8 "%STOW_ROOT%\bin\stow" > "%STOW_ROOT%\doc\stow.8"

    set STARTING_DIR=%CD%
    cd /d "%STOW_ROOT%"
    echo ##[cmd] %STOW_PERL% -I "%STOW_ROOT%\lib" -I "%STOW_ROOT%\bin" "%STOW_ROOT%\Build.PL"
    %STOW_PERL% -I "%STOW_ROOT%\lib" -I "%STOW_ROOT%\bin" "%STOW_ROOT%\Build.PL"
    cd /d "%STARTING_DIR%"

    echo ##[cmd] %STOW_PERL% -I "%STOW_ROOT%\lib" "%STOW_ROOT%\bin\stow" --version
    %STOW_PERL% -I "%STOW_ROOT%\lib" "%STOW_ROOT%\bin\stow" --version
exit /b

:ReplaceVariables
    setlocal EnableExtensions EnableDelayedExpansion

    set input_file=%~1.in
    set output_file=%~1

    :: This is more explicit and reliable than the config file trick
    set _cmd=%STOW_PERL% -p -e "s/\@STOW_PERL\@/$ENV{STOW_PERL}/g;" -e "s/\@VERSION\@/$ENV{STOW_VERSION}/g;" -e "s/\@USE_LIB_PMDIR\@/$ENV{USE_LIB_PMDIR}/g;" "%input_file%"
    echo ##[cmd] %_cmd%
    %_cmd% >"%output_file%"
    echo Generated output: '%output_file%'
endlocal & exit /b
