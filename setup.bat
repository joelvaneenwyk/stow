@echo off

call :SetupStow "%~dp0"

exit /b

::
:: Local functions
::

:SetupStow
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%

    call "%STOW_ROOT%\tools\make-clean.bat"
    if not "!ERRORLEVEL!"=="0" exit /b !ERRORLEVEL!

    call "%STOW_ROOT%\tools\install-dependencies.bat"
    if not "!ERRORLEVEL!"=="0" exit /b !ERRORLEVEL!

    call "%STOW_ROOT%\tools\make-stow.bat"
    if not "!ERRORLEVEL!"=="0" exit /b !ERRORLEVEL!

    call "%STOW_ROOT%\tools\run-tests.bat"
endlocal & exit /b
