@echo off
::
:: This file is part of GNU Stow.
::
:: GNU Stow is free software: you can redistribute it and/or modify it
:: under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.
::
:: GNU Stow is distributed in the hope that it will be useful, but
:: WITHOUT ANY WARRANTY; without even the implied warranty of
:: MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
:: General Public License for more details.
::
:: You should have received a copy of the GNU General Public License
:: along with this program. If not, see https://www.gnu.org/licenses/.
::

call :Clean "%~dp0..\" %*
exit /b

:Clean
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%

    for /f %%a in ('perl %STOW_ROOT%\tools\get-version') do set "STOW_VERSION=%%a"
    for /f %%a in ('perl -MCPAN -e "use Config; print $Config{privlib};"') do set "PERL_LIB=%%a"

    :: Shut down 'gpg-agent' otherwise some files can't be deleted from 'msys64' folder
    if exist "%STOW_ROOT%\msys64\usr\bin\gpg-agent.exe" (
        wmic process where ExecutablePath='%STOW_ROOT%\msys64\usr\bin\gpg-agent.exe' delete
    )

    :: Shut down 'dirmngr' otherwise some files can't be deleted from 'msys64' folder
    if exist "%STOW_ROOT%\msys64\usr\bin\dirmngr.exe" (
        wmic process where ExecutablePath='%STOW_ROOT%\msys64\usr\bin\dirmngr.exe' delete
    )

    set PERL_CPAN_CONFIG=%PERL_LIB%\CPAN\Config.pm
    del "!PERL_CPAN_CONFIG!" > nul 2>&1
    echo Removed CPAN config: '!PERL_CPAN_CONFIG!'

    if "%~2"=="--all" (
        rmdir /q /s "%STOW_ROOT%\.tmp\msys64\" > nul 2>&1
        echo Removed local 'MSYS2' install.
    )

    :: This is where 'cpan' files live when run through MSYS2 so this will force Perl
    :: modules to be reinstalled.
    rmdir /q /s "%STOW_ROOT%\.tmp\home\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\.tmp\temp\" > nul 2>&1

    del "\\?\%STOW_ROOT%\nul" > nul 2>&1
    del "%STOW_ROOT%\texput.log" > nul 2>&1
    del "%STOW_ROOT%\Build" > nul 2>&1
    del "%STOW_ROOT%\Build.bat" > nul 2>&1
    del "%STOW_ROOT%\config.*" > nul 2>&1
    del "%STOW_ROOT%\configure" > nul 2>&1
    del "%STOW_ROOT%\configure~" > nul 2>&1
    del "%STOW_ROOT%\configure.lineno" > nul 2>&1
    del "%STOW_ROOT%\Makefile" > nul 2>&1
    del "%STOW_ROOT%\Makefile.in" > nul 2>&1
    del "%STOW_ROOT%\MYMETA.json" > nul 2>&1
    del "%STOW_ROOT%\MYMETA.yml" > nul 2>&1
    del "%STOW_ROOT%\ChangeLog" > nul 2>&1
    del "%STOW_ROOT%\stow-*.tar.bz2" > nul 2>&1
    del "%STOW_ROOT%\stow-*.tar.gz" > nul 2>&1
    del "%STOW_ROOT%\test_results*.xml" > nul 2>&1
    del "%STOW_ROOT%\bin\chkstow" > nul 2>&1
    del "%STOW_ROOT%\bin\stow" > nul 2>&1
    del "%STOW_ROOT%\lib\Stow\Util.pm" > nul 2>&1
    del "%STOW_ROOT%\lib\Stow.pm" > nul 2>&1
    del "%STOW_ROOT%\doc\.dirstamp" > nul 2>&1
    del "%STOW_ROOT%\doc\stamp-vti" > nul 2>&1
    del "%STOW_ROOT%\doc\stow.8" > nul 2>&1
    del "%STOW_ROOT%\doc\stow.aux" > nul 2>&1
    del "%STOW_ROOT%\doc\stow.cp" > nul 2>&1
    del "%STOW_ROOT%\doc\stow.info" > nul 2>&1
    del "%STOW_ROOT%\doc\stow.log" > nul 2>&1
    del "%STOW_ROOT%\doc\stow.pdf" > nul 2>&1
    del "%STOW_ROOT%\doc\stow.toc" > nul 2>&1
    del "%STOW_ROOT%\doc\version.texi" > nul 2>&1
    del "%STOW_ROOT%\doc\manual-single.html" > nul 2>&1
    del "%STOW_ROOT%\doc\manual.pdf" > nul 2>&1
    del "%STOW_ROOT%\automake\install-sh" > nul 2>&1
    del "%STOW_ROOT%\automake\mdate-sh" > nul 2>&1
    del "%STOW_ROOT%\automake\missing" > nul 2>&1
    del "%STOW_ROOT%\automake\test-driver" > nul 2>&1
    del "%STOW_ROOT%\automake\texinfo.tex" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\_build\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\_Inline\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\bin\_Inline\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\tools\_Inline\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\_test\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\autom4te.cache\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\blib\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\doc\manual-split\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\stow\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\cover_db\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\tmp-testing-trees\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\tools\tmp-testing-trees\" > nul 2>&1
    rmdir /q /s "%STOW_ROOT%\stow-!STOW_VERSION!\" > nul 2>&1

    git -C "%STOW_ROOT%" checkout -- "%STOW_ROOT%\aclocal.m4" > nul 2>&1

    echo Removed intermediate Stow files from root: '%STOW_ROOT%'
exit /b 0
