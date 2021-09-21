@echo off

call "%~dp0make-stow.bat"

call :RunStowTests "%~dp0..\"
exit /b

:RunStowTests
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%
    set "STOW_ROOT=%STOW_ROOT:\=/%"

    set _cmd=call prove -I "%STOW_ROOT%/t/" -I "%STOW_ROOT%/bin/" -I "%STOW_ROOT%/lib/" --timer --formatter TAP::Formatter::JUnit "%STOW_ROOT%/t/"
    echo ##[cmd] %_cmd%
    %_cmd%
endlocal & exit /b
