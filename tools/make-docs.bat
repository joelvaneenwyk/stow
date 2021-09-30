@echo off

call :MakeDocs "%~dp0..\"
exit /b

:MakeDocs
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%
    set STOW_ROOT_UX=%STOW_ROOT:\=/%

    :: Make sure we start from a clean slate to prevent variability in tests
    call "%STOW_ROOT%\tools\make-clean.bat"

    set STOW_PERL=perl
    set TMPDIR=%STOW_ROOT%\.tmp

    set WIN_UNIX_DIR=%STOW_ROOT%\.tmp\ezwinports
    set WIN_UNIX_DIR_UX=%WIN_UNIX_DIR:\=/%

    ::set PERL5LIB=%WIN_UNIX_DIR_UX%/share/automake-1.11:%WIN_UNIX_DIR_UX%/share/autoconf
    ::set PERL5LIB=%PERL5LIB:\=/%

    set PERL_INCLUDE_UX=-I %WIN_UNIX_DIR_UX%/share/automake-1.11 -I %WIN_UNIX_DIR_UX%/share/autoconf
    set PERL=perl %PERL_INCLUDE_UX%

    set BASH=%WIN_UNIX_DIR%\usr\bin\bash.exe
    ::set AUTORECONF=%PERL% %WIN_UNIX_DIR_UX%/bin/autoreconf
    ::set AUTOCONF=%BASH% %WIN_UNIX_DIR_UX%/bin/autoconf
    ::set AUTOHEADER=%PERL% %WIN_UNIX_DIR_UX%/bin/autoheader
    ::set AUTOM4TE=%PERL% %WIN_UNIX_DIR_UX%/bin/autom4te
    ::set AUTOMAKE=%PERL% %WIN_UNIX_DIR_UX%/bin/automake
    ::set ACLOCAL=%PERL% %WIN_UNIX_DIR_UX%/bin/aclocal
    ::set LIBTOOLIZE=libtoolize
    ::set AUTOPOINT=autopoint
    ::set MAKE=make
    ::set WARNINGS=""

    set autom4te_perllibdir=%WIN_UNIX_DIR_UX%/share/autoconf
    set perllibdir=%WIN_UNIX_DIR_UX%/share/aclocal-1.11
    set ACLOCAL_PATH=%WIN_UNIX_DIR_UX%/share/aclocal-1.11

    ::set PATH=%WIN_UNIX_DIR%\bin;%WIN_UNIX_DIR%\mingw32\bin;%PATH%
    ::set PATH=%WIN_UNIX_DIR%\bin;%gitdir%\cmd;%WIN_UNIX_DIR%\usr\bin;%WIN_UNIX_DIR%\usr\bin\core_perl;%WIN_UNIX_DIR%\mingw32\bin
    ::set PATH=%PATH:\=/%
    set PATH=%WIN_UNIX_DIR%\bin

    set HOME=%STOW_ROOT%
    set MSYS2_PATH_TYPE=inherit
    set MSYS=winsymlinks:nativestrict
    set MSYSTEM=MSYS

    set _cd=%CD%

    if exist "%WIN_UNIX_DIR%\post-install.bat" (
        cd /d "%WIN_UNIX_DIR%"
        call "%WIN_UNIX_DIR%\post-install.bat"
        REM "%WIN_UNIX_DIR%\git-bash.exe" --no-needs-console --hide --no-cd --command="%WIN_UNIX_DIR%\post-install.bat"
        echo Executed post install script.
    )

    cd /d "%STOW_ROOT%"
    %BASH% --login -c "source /etc/profile && which autoreconf"

    ::%AUTORECONF% --install --verbose
    ::%BASH% --noprofile --norc autoreconf --install --verbose

    ::%PERL% -V:siteprefix
    ::%BASH% --noprofile --norc configure --prefix= --with-pmdir="%PERL5LIB%"
    ::make bin/stow bin/chkstow lib/Stow.pm lib/Stow/Util.pm

    cd /d "%_cd%"
exit /b

:MakeDocsCustom
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%

    echo @set UPDATED 0 0 0 >"%STOW_ROOT%\doc\version.texi"
    echo @set UPDATED-MONTH ${2:-0} ${3:-0} >"%STOW_ROOT%\doc\version.texi"
    echo @set EDITION $VERSION >"%STOW_ROOT%\doc\version.texi"
    echo @set VERSION $VERSION >"%STOW_ROOT%\doc\version.texi"

    set _perl_inc=-I tools\texinfo\tp\ -I tools\texinfo\tp\Texinfo\ -I tools\texinfo\tp\maintain\lib\Unicode-EastAsianWidth\lib\ -I tools\texinfo\tp\maintain\lib\libintl-perl\lib -I tools\texinfo\tp\maintain\lib\Text-Unidecode\lib\
    set _cmd=perl %_perl_inc% "%STOW_ROOT%\tools\texinfo\tp\texi2any.pl" -I doc\ -o doc\ doc\stow.texi
    echo ##[cmd] %_cmd%
    %_cmd%
exit /b 0
