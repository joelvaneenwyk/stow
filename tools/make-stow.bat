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

    set USE_LIB_PMDIR=

    set PMDIR=%STOW_ROOT%\lib
    set PMDIR=%PMDIR:\=/%

    :: Print Perl version number
    %STOW_PERL% -e "print 'Perl v' . substr($^V, 1) . ""\n"""
    if errorlevel 1 (
        echo Perl executable invalid or missing: '%STOW_PERL%'
        exit /b 1
    )

    :: Get Stow version number
    for /f %%a in ('%STOW_PERL% %STOW_ROOT%\tools\get-version') do set "STOW_VERSION=%%a"

    set _inc=0
    for /f "tokens=*" %%a in ('%STOW_PERL% -V') do (
        if "!_inc!"=="1" (
            echo %%a | findstr /C:"%PMDIR%" > nul 2>&1

            if not errorlevel 1 (
                set PERL5LIB=%%a
                echo Target folder '!PMDIR!' is part of built-in @INC, so everything
                echo should work fine with no extra include statements.
                goto:$PMCheckDone
            )
        )
        if "%%a"=="@INC:" (
            set _inc=1
        )
    )
    :$PMCheckDone

    if not "!PERL5LIB!"=="" goto:$Initialized

    set USE_LIB_PMDIR=use lib "%PMDIR%";
    set PERL5LIB=!PMDIR!
    echo Target folder is not part of built-in @INC, so the
    echo front-end scripts will add an appropriate "use lib" line
    echo to compensate.

    :$Initialized

    echo Stow v!STOW_VERSION!
    echo PERL5LIB: '!PERL5LIB!'

    if not exist "%STOW_ROOT%\doc" mkdir "%STOW_ROOT%\doc"

    :: Configure and make approach not yet working so we
    :: generate final Perl libraries manually.
    ::call :RunMake

    call :ReplaceVariables "%STOW_ROOT%\bin\chkstow"
    call :ReplaceVariables "%STOW_ROOT%\bin\stow"
    call :ReplaceVariables "%STOW_ROOT%\lib\Stow\Util.pm"

    call :ReplaceVariables "%STOW_ROOT%\lib\Stow.pm"
    type "%STOW_ROOT%\default-ignore-list" >> "%STOW_ROOT%\lib\Stow.pm"

    call pod2man --name stow --section 8 "%STOW_ROOT%\bin\stow" > "%STOW_ROOT%\doc\stow.8"

    set _cd=%CD%
    cd /d "%STOW_ROOT%"
    echo ##[cmd] %STOW_PERL% -I "%STOW_ROOT%\lib" -I "%STOW_ROOT%\bin" "%STOW_ROOT%\Build.PL"
    %STOW_PERL% -I "%STOW_ROOT%\lib" -I "%STOW_ROOT%\bin" "%STOW_ROOT%\Build.PL"
    cd /d "%_cd%"

    :: Remove all intermediate files before running Stow for the first time
    rmdir /q /s "%STOW_ROOT%\_Inline\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\bin\_Inline\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\tools\_Inline\" > nul 2>&1

    echo ##[cmd] %STOW_PERL% -I "%STOW_ROOT%\lib" "%STOW_ROOT%\bin\stow" --version
    %STOW_PERL% -I "%STOW_ROOT%\lib" "%STOW_ROOT%\bin\stow" --version
endlocal & exit /b

:RunMake
    setlocal EnableExtensions EnableDelayedExpansion

    set STOW_ROOT_UX=%STOW_ROOT:\=/%

    set GNU_UNIX_DIR=%STOW_ROOT%\.tmp\ezwinports
    set GNU_UNIX_DIR_UX=%GNU_UNIX_DIR:\=/%

    set PERL5LIB=%GNU_UNIX_DIR_UX%/share/automake-1.11:%GNU_UNIX_DIR_UX%/share/autoconf
    set PERL5LIB=%PERL5LIB:\=/%

    set PERL5INC=-I %GNU_UNIX_DIR_UX%/share/automake-1.11 -I %GNU_UNIX_DIR_UX%/share/autoconf
    set PERL_BIN=perl %PERL5INC%

    set PATH=%GNU_UNIX_DIR%\bin;%GNU_UNIX_DIR%\mingw32\bin;%PATH%

    set SHELL_BIN=%GNU_UNIX_DIR%\bin\sh
    set SHELL=%GNU_UNIX_DIR_UX%/bin/sh
    set AUTORECONF=%PERL_BIN% %GNU_UNIX_DIR_UX%/bin/autoreconf
    set AUTOCONF=%SHELL_BIN% %GNU_UNIX_DIR_UX%/bin/autoconf
    set AUTOHEADER=%PERL_BIN% %GNU_UNIX_DIR_UX%/bin/autoheader
    set AUTOM4TE=%PERL_BIN% %GNU_UNIX_DIR_UX%/bin/autom4te
    set AUTOMAKE=%PERL_BIN% %GNU_UNIX_DIR_UX%/bin/automake
    set ACLOCAL=%PERL_BIN% %GNU_UNIX_DIR_UX%/bin/aclocal
    set LIBTOOLIZE=libtoolize
    set AUTOPOINT=autopoint
    set MAKE=make

    set autom4te_perllibdir=%GNU_UNIX_DIR_UX%/share/autoconf
    set perllibdir=%GNU_UNIX_DIR_UX%/share/aclocal-1.11
    set ACLOCAL_PATH=%GNU_UNIX_DIR_UX%/share/aclocal-1.11

    set _cd=%CD%

    cd /d "%STOW_ROOT%"
    %SHELL_BIN% "%STOW_ROOT_UX%/tools/make-stow.sh"

    %AUTORECONF% --version
    %AUTORECONF% --install --verbose
    %PERL_BIN% -V:siteprefix

    %SHELL% configure --prefix= --with-pmdir="%PERL5LIB%"
    make bin/stow bin/chkstow lib/Stow.pm lib/Stow/Util.pm

    cd /d "%_cd%"
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
