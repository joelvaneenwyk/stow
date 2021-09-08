@echo off

powershell -NoLogo -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -scope CurrentUser;"
powershell -NoLogo -NoProfile -File "%~dp0install-texlive.ps1"

call :InstallTexLive "%~dp0..\"
exit /b

:InstallTexLive
    setlocal EnableExtensions EnableDelayedExpansion

    set _root=%~dp1
    set STOW_ROOT=%_root:~0,-1%
    set BUILD_TEMP_ROOT=%STOW_ROOT%\.build

    set TEXLIVE_ROOT=%BUILD_TEMP_ROOT%\texlive-install
    set TEXLIVE_INSTALL=%TEXLIVE_ROOT%\install-tl-windows.bat

    set TEXDIR=%BUILD_TEMP_ROOT%\texlive
    set TEXLIVE_BIN=%TEXDIR%\bin\win32
    set TEXMFCONFIG=%TEXDIR%\texmf-config
    set TEXMFHOME=%TEXDIR%\texmf-local
    set TEXMFLOCAL=%TEXDIR%\texmf-local
    set TEXMFSYSCONFIG=%TEXDIR%\texmf-config
    set TEXMFSYSVAR=%TEXDIR%\texmf-var
    set TEXMFVAR=%TEXDIR%\texmf-var

    set TEXLIVE_INSTALL_PREFIX=%TEXDIR%
    set TEXLIVE_INSTALL_TEXDIR=%TEXDIR%
    set TEXLIVE_INSTALL_TEXMFCONFIG=%TEXDIR%\texmf-config
    set TEXLIVE_INSTALL_TEXMFHOME=%TEXDIR%\texmf-local
    set TEXLIVE_INSTALL_TEXMFLOCAL=%TEXDIR%\texmf-local
    set TEXLIVE_INSTALL_TEXMFSYSCONFIG=%TEXDIR%\texmf-config
    set TEXLIVE_INSTALL_TEXMFSYSVAR=%TEXDIR%\texmf-var
    set TEXLIVE_INSTALL_TEXMFVAR=%TEXDIR%\texmf-var

    set _texInstallCommand="%TEXLIVE_INSTALL%" -no-gui -portable -profile "%STOW_ROOT%\tools\install-texlive.profile"
    if not exist "%TEXLIVE_BIN%\tex.exe" (
        echo ##[cmd] %_texInstallCommand%
        call %_texInstallCommand%
    ) else (
        echo Skipped install. Tex executable already exists: '%TEXLIVE_BIN%\tex.exe'
    )
exit /b 0
