@echo off

call :MakeDocs "%~dp0..\"
exit /b

:MakeDocs
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%
exit /b 0
