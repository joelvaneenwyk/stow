@echo off

call "%~dp0make-clean.bat"

call :MakeStow "%~dp0..\"
exit /b

:MakeStow
    setlocal EnableExtensions EnableDelayedExpansion

    set STOW_ROOT=%~dp1
    set VERSION=2.3.2
    set PERL=perl
    set PMDIR=%prefix%/perl/site/lib
    set USE_LIB_PMDIR=

    %PERL% --version
    if errorlevel 1 (
        echo Invalid or missing Perl executable: '%PERL%'
        exit /b 1
    )

    set _inc=0
    for /f "tokens=*" %%a in ('%PERL% -V') do (
        if "!_inc!"=="1" (
            echo %%a | findstr /C:"%PMDIR%" 1>nul

            if not errorlevel 1 (
                set PERL5LIB=%%a
                echo # This is in %PERL%'s built-in @INC, so everything
                echo # should work fine with no extra effort.
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
        echo This is *not* in %PERL%'s built-in @INC, so the
        echo front-end scripts will have an appropriate "use lib"
        echo line inserted to compensate.
    )

    echo.
    echo PERL5LIB: '!PERL5LIB!'

    call :edit "%STOW_ROOT%\bin\chkstow"

    call :edit "%STOW_ROOT%\bin\stow"
    if not exist "%STOW_ROOT%\doc" mkdir "%STOW_ROOT%\doc"
    call pod2man --name stow --section 8 "%STOW_ROOT%\bin\stow" > "%STOW_ROOT%\doc\stow.8"

    call :edit "%STOW_ROOT%\lib\Stow\Util.pm"

    call :edit "%STOW_ROOT%\lib\Stow.pm"
    type "%STOW_ROOT%\default-ignore-list" >> "%STOW_ROOT%\lib\Stow.pm"

    call "%~dp0install-dependencies.bat"
    %PERL% "%STOW_ROOT%\Build.PL"
    call "%STOW_ROOT%\Build.bat" installdeps
    call "%STOW_ROOT%\Build.bat" build
exit /b 0

:edit
    set input_file=%~1.in
    set output_file=%~1

    :: This is more explicit and reliable than the config file trick
    set _cmd=%PERL% -p -e "s/\@PERL\@/$ENV{PERL}/g;" -e "s/\@VERSION\@/$ENV{VERSION}/g;" -e "s/\@USE_LIB_PMDIR\@/$ENV{USE_LIB_PMDIR}/g;" "%input_file%"
    echo ##[cmd] %_cmd%
    %_cmd% >"%output_file%"
    echo Generated output: '%output_file%'
exit /b 0
