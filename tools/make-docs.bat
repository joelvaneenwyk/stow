@echo off

call :MakeDocs "%~dp0..\"
exit /b

:MakeDocs
    setlocal EnableExtensions EnableDelayedExpansion

    set STOW_ROOT=%~dp1
exit /b 0
