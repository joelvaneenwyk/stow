@echo off

::powershell -Command "Set-ExecutionPolicy RemoteSigned -scope CurrentUser; "
powershell -File "%~dp0texlive-install.ps1"

set TEXLIVE_ROOT=%~dp0..\_build\texlive-install
set TEXDIR=%~dp0..\_build\texlive

set TEXLIVE_INSTALL=%TEXLIVE_ROOT%\install-tl-windows.bat
set TEXLIVE_BIN=%TEXDIR%\texlive\bin\win32

set TEXMFCONFIG=%TEXDIR%\texlive\texmf-config
set TEXMFHOME=%TEXDIR%\texlive\texmf-local
set TEXMFLOCAL=%TEXDIR%\texlive\texmf-local
set TEXMFSYSCONFIG=%TEXDIR%\texlive\texmf-config
set TEXMFSYSVAR=%TEXDIR%\texlive\texmf-var
set TEXMFVAR=%TEXDIR%\texlive\texmf-var

set TEXLIVE_INSTALL_PREFIX=%TEXDIR%\texlive
set TEXLIVE_INSTALL_TEXDIR=%TEXDIR%\texlive
set TEXLIVE_INSTALL_TEXMFCONFIG=%TEXDIR%\texlive\texmf-config
set TEXLIVE_INSTALL_TEXMFHOME=%TEXDIR%\texlive\texmf-local
set TEXLIVE_INSTALL_TEXMFLOCAL=%TEXDIR%\texlive\texmf-local
set TEXLIVE_INSTALL_TEXMFSYSCONFIG=%TEXDIR%\texlive\texmf-config
set TEXLIVE_INSTALL_TEXMFSYSVAR=%TEXDIR%\texlive\texmf-var
set TEXLIVE_INSTALL_TEXMFVAR=%TEXDIR%\texlive\texmf-var

set _texInstallCommand="%TEXLIVE_INSTALL%" -no-gui -portable -profile "%~dp0texlive-install.profile"
if not exist "%TEXLIVE_BIN%\texi2dvi.exe" (
    echo %_texInstallCommand%
    call %_texInstallCommand%
)
