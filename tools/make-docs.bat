@echo off

call :MakeDocs "%~dp0..\"

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

:MakeDocs
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

    :: Print Perl version number
    %STOW_PERL% -e "print 'Perl v' . substr($^V, 1) . ""\n"""
    if errorlevel 1 (
        echo Perl executable invalid or missing: '%STOW_PERL%'
        exit /b 1
    )

    :: Get Stow version number
    for /f %%a in ('%STOW_PERL% %STOW_ROOT%\tools\get-version') do set "STOW_VERSION=%%a"

    set PERL_INCLUDE_UX=-I %WIN_UNIX_DIR_UX%/share/automake-1.11 -I %WIN_UNIX_DIR_UX%/share/autoconf
    set PERL=perl %PERL_INCLUDE_UX%

    set SHELL=%WIN_UNIX_DIR%\bin\sh.exe

    set GUILE_LOAD_PATH=%WIN_UNIX_DIR%\usr\share\guile\2.0
    set GUILE_LOAD_COMPILED_PATH=%WIN_UNIX_DIR%\usr\lib\guile\2.0\ccache

    set PATH_ORIGINAL=%PATH%
    set TEX=%TMPDIR%\texlive\bin\win32\tex.exe

    set HOME=%STOW_BUILD_TOOLS_ROOT%\home
    if not exist "%HOME%" mkdir "%HOME%"

    set MSYS2_PATH_TYPE=inherit
    set MSYS=winsymlinks:nativestrict
    set MSYSTEM=MSYS

    echo Stow v!STOW_VERSION!

    if exist "%WIN_UNIX_DIR%\post-install.bat" (
        cd /d "%WIN_UNIX_DIR%"
        call :Run call "%WIN_UNIX_DIR%\post-install.bat"
        REM call :Run "%WIN_UNIX_DIR%\git-bash.exe" --no-needs-console --hide --no-cd --command="%WIN_UNIX_DIR%\post-install.bat"
        echo Executed post install script.
    )

    :: Make sure we start from a clean slate to prevent variability in tests
    call :Run call "%STOW_ROOT%\tools\make-clean.bat"

    call :MakeDocsCustom "%~dp0..\"

    set BASH="%WIN_UNIX_DIR%\usr\bin\bash.exe" --noprofile --norc -c

    cd /d "%STOW_ROOT%"
    set PATH=%WIN_UNIX_DIR%\usr\bin;%WIN_UNIX_DIR%\bin;%TMPDIR%\texlive\bin\win32;%WIN_UNIX_DIR%\usr\bin\core_perl;%WIN_UNIX_DIR%\mingw32\bin
    call :Run %BASH% "source ./tools/stow-lib.sh && install_system_base_dependencies"
    call :Run %BASH% "autoreconf --install --verbose"
    call :Run %BASH% "./configure --prefix='' --with-pmdir='%PERL5LIB%'"
    call :Run %BASH% "make doc/manual.pdf"
    call :Run %BASH% "make bin/stow bin/chkstow lib/Stow.pm lib/Stow/Util.pm"
    call :Run %BASH% "make doc/manual-single.html"

    :$MakeDocsEnd
        :: Restore original directory
        cd /d "%_cd%"
exit /b

:MakeDocsCustom
    setlocal EnableExtensions EnableDelayedExpansion

    echo @set UPDATED 0 0 0 >"%STOW_VERSION_TEXI%"
    echo @set UPDATED-MONTH ${2:-0} ${3:-0} >>"%STOW_VERSION_TEXI%"
    echo @set EDITION !STOW_VERSION! >>"%STOW_VERSION_TEXI%"
    echo @set VERSION !STOW_VERSION! >>"%STOW_VERSION_TEXI%"

    set PERL_INCLUDE=-I %WIN_UNIX_DIR_UX%/usr/share/automake-1.16
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UX%/usr/share/autoconf
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UX%/usr/share/texinfo
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UX%/usr/share/texinfo/lib/libintl-perl/lib
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UX%/usr/share/texinfo/lib/Text-Unidecode/lib
    set PERL_INCLUDE=!PERL_INCLUDE! -I %WIN_UNIX_DIR_UX%/usr/share/texinfo/lib/Unicode-EastAsianWidth/lib

    :: Generate 'stow.info'
    cd "%STOW_ROOT%"
    call :Run perl %PERL_INCLUDE% "%WIN_UNIX_DIR%\usr\bin\texi2any" -I doc\ -o doc\ doc\stow.texi
    echo Generated 'doc\stow.info'
exit /b 0
