@echo off

call :MakeDocs "%~dp0..\"
exit /b

:MakeDocs
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%

    call "%~dp0install-texlive.bat"

    echo @set UPDATED 0 0 0 >"%STOW_ROOT%\doc\version.texi"
    echo @set UPDATED-MONTH ${2:-0} ${3:-0} >"%STOW_ROOT%\doc\version.texi"
    echo @set EDITION $VERSION >"%STOW_ROOT%\doc\version.texi"
    echo @set VERSION $VERSION >"%STOW_ROOT%\doc\version.texi"

    set _perl_inc=-I tools\texinfo\tp\ -I tools\texinfo\tp\Texinfo\ -I tools\texinfo\tp\maintain\lib\Unicode-EastAsianWidth\lib\ -I tools\texinfo\tp\maintain\lib\libintl-perl\lib -I tools\texinfo\tp\maintain\lib\Text-Unidecode\lib\
    set _cmd=perl %_perl_inc% "%STOW_ROOT%\tools\texinfo\tp\texi2any.pl" -I doc\ -o doc\ doc\stow.texi
    echo ##[cmd] %_cmd%
    %_cmd%
exit /b 0
