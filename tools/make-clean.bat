@echo off

call :Clean "%~dp0..\"
exit /b

:Clean
    setlocal EnableExtensions EnableDelayedExpansion

    set STOW_ROOT=%~dp1
    del "%STOW_ROOT%\Build" > nul 2>&1
    del "%STOW_ROOT%\Build.bat" > nul 2>&1
    del "%STOW_ROOT%\config.*" > nul 2>&1
    del "%STOW_ROOT%\configure" > nul 2>&1
    del "%STOW_ROOT%\Makefile" > nul 2>&1
    del "%STOW_ROOT%\Makefile.in" > nul 2>&1
    del "%STOW_ROOT%\MYMETA.json" > nul 2>&1
    del "%STOW_ROOT%\MYMETA.yml" > nul 2>&1
    del "%STOW_ROOT%\doc\.dirstamp" > nul 2>&1
    del "%STOW_ROOT%\doc\stamp-vti" > nul 2>&1
    del "%STOW_ROOT%\doc\stow.8" > nul 2>&1
    del "%STOW_ROOT%\doc\stow.info" > nul 2>&1
    del "%STOW_ROOT%\doc\version.texi" > nul 2>&1
    del "%STOW_ROOT%\bin\chkstow" > nul 2>&1
    del "%STOW_ROOT%\bin\stow" > nul 2>&1
    del "%STOW_ROOT%\lib\Stow\Util.pm" > nul 2>&1
    del "%STOW_ROOT%\lib\Stow.pm" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\_build\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\_Inline\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\bin\_Inline\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\_test\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\autom4te.cache\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\blib\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\stow\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\cover_db\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\tmp-testing-trees\" > nul 2>&1
exit /b 0
