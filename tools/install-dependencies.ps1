﻿<#
This file is part of GNU Stow.

GNU Stow is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GNU Stow is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see https://www.gnu.org/licenses/.

.NOTES
    ===========================================================================
    Created on:   September 2021
    Created by:   Joel Van Eenwyk
    Filename:     install-dependencies.ps1
    ===========================================================================

.DESCRIPTION
    Install dependencies needed for building GNU tools.
#>

using namespace System.Net.Http;

Function Expand-File {
    <#
.SYNOPSIS
    Extract an archive using 7zip if available otherwise use built-in utilities.
.DESCRIPTION
    Downloads a file
.PARAMETER Url
    URL to file/resource to download
.PARAMETER Filename
    file to save it as locally
.EXAMPLE
    C:\PS> Get-File -Name "mynuget.exe" -Url https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
    #>
    Param(
        [Parameter(Position = 0, mandatory = $true)]
        [string]$DestinationPath,
        [string]$Path = ''
    )

    if (![System.IO.Path]::IsPathRooted($DestinationPath)) {
        $DestinationPath = Join-Path (Get-Item -Path "./" -Verbose).FullName $DestinationPath
    }

    if (![System.IO.Path]::IsPathRooted($Path)) {
        $Path = Join-Path (Get-Item -Path "./" -Verbose).FullName $Path
    }

    $7zip = ""

    if ($IsWindows -or $ENV:OS) {
        $7za920zip = Join-Path -Path "$script:ArchivesDir" -ChildPath "7za920.zip"
        $7za920 = Join-Path -Path "$script:TempDir" -ChildPath "7za920"

        # Download 7zip that was stored in a zip file so that we can extract the latest version stored in 7z format
        if (-not(Test-Path -Path "$7za920zip" -PathType Leaf)) {
            Get-File -Url "https://www.7-zip.org/a/7za920.zip" -Filename "$7za920zip"
        }

        # Extract previous version of 7zip first
        if (Test-Path -Path "$7za920zip" -PathType Leaf) {
            if (-not(Test-Path -Path "$7za920/7za.exe" -PathType Leaf)) {
                $ProgressPreference = 'SilentlyContinue'
                Expand-Archive -Path "$7za920zip" -DestinationPath "$7za920"
            }
        }

        # If older vresion is available, download and extract latest
        if (Test-Path -Path "$7za920/7za.exe" -PathType Leaf) {
            $7z2103zip = Join-Path -Path "$script:ArchivesDir" -ChildPath "7z2103-extra.7z"
            $7z2103 = Join-Path -Path "$script:TempDir" -ChildPath "7z2103"

            # Download latest version of 7zip
            if (-not(Test-Path -Path "$7z2103zip" -PathType Leaf)) {
                Get-File -Url "https://www.7-zip.org/a/7z2103-extra.7z" -Filename "$7z2103zip"
            }

            # Extract latest vesrion using old version
            if (Test-Path -Path "$7z2103zip" -PathType Leaf) {
                if (-not(Test-Path -Path "$7z2103/7za.exe" -PathType Leaf)) {
                    & "$7za920/7za.exe" x "$7z2103zip" -aoa -o"$7z2103" -r -y | Out-Default
                }
            }
        }

        # Specify latest version of 7zip so that we can use it below
        if (Test-Path -Path "$7z2103/x64/7za.exe" -PathType Leaf) {
            $7zip = "$7z2103/x64/7za.exe"
        }
    }
    else {
        $7z2103zip = Join-Path -Path "$script:ArchivesDir" -ChildPath "7z2103-linux-x64.tar.xz"
        $7z2103 = Join-Path -Path "$script:TempDir" -ChildPath "7z2103"

        # Download 7zip that was stored in a zip file so that we can extract the latest version stored in 7z format
        if (-not(Test-Path -Path "$7z2103zip" -PathType Leaf)) {
            Get-File -Url "https://www.7-zip.org/a/7z2103-linux-x64.tar.xz" -Filename "$7z2103zip"
        }

        # Extract previous version of 7zipTempDir first
        if (Test-Path -Path "$7z2103zip" -PathType Leaf) {
            if ( -not(Test-Path -Path "$7z2103") ) {
                New-Item -ItemType directory -Path "$7z2103" | Out-Null
            }

            if (-not(Test-Path -Path "$7z2103/7zz" -PathType Leaf)) {
                tar -xvf "$7z2103zip" -C "$7z2103"
            }
        }

        if (Test-Path -Path "$7z2103/7zz" -PathType Leaf) {
            $7zip = "$7z2103/7zz"
        }
    }

    try {
        Write-Host "Extracting archive: '$Path'"
        if (Test-Path -Path "$7zip" -PathType Leaf) {
            & "$7zip" x "$Path" -aoa -o"$DestinationPath" -r -y | Out-Default
        }
        else {
            $ProgressPreference = 'SilentlyContinue'
            Expand-Archive -Path "$Path" -DestinationPath "$DestinationPath" -Force
        }
        Write-Host "Extracted archive to target: '$DestinationPath'"
    }
    catch {
        throw "Failed to extract archive: $Path"
    }
}

Function Get-File {
    <#
.SYNOPSIS
    Downloads a file
.DESCRIPTION
    Downloads a file
.PARAMETER Url
    URL to file/resource to download
.PARAMETER Filename
    file to save it as locally
.EXAMPLE
    C:\PS> Get-File -Name "mynuget.exe" -Url https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
#>

    Param(
        [Parameter(Position = 0, mandatory = $true)]
        [string]$Url,
        [string]$Filename = ''
    )

    # Get filename
    if (!$Filename) {
        $Filename = [System.IO.Path]::GetFileName($Url)
    }

    # Convert local/relative path to absolute path
    if (![System.IO.Path]::IsPathRooted($Filename)) {
        $FilePath = Join-Path (Get-Item -Path "./" -Verbose).FullName $Filename
    } else {
        $FilePath = $Filename
    }

    $FilePathOut = "$FilePath.out"

    if ($null -eq ($Url -as [System.URI]).AbsoluteURI) {
        throw "⚠ Invalid Url: $Url"
    }
    elseif (Test-Path -Path "$FilePath" -PathType Leaf) {
        Write-Host "File already available: '$FilePath'"
    }
    else {
        Write-Host "Target: '$FilePathOut'"
        $handler = $null
        $webclient = $null

        try {
            $webclient = New-Object System.Net.WebClient
            Write-Host "[web.client] Downloading: $Url"
            $webclient.DownloadFile([System.Uri]::new($Url), "$FilePathOut")
        }
        catch {
            try {
                $handler = New-Object -TypeName System.Net.Http.HttpClientHandler
                $handler = New-Object -TypeName System.Net.Http.HttpClientHandler
                $client = New-Object -TypeName System.Net.Http.HttpClient -ArgumentList $handler
                $client.Timeout = New-Object -TypeName System.TimeSpan -ArgumentList 0, 30, 0
                $cancelTokenSource = [System.Threading.CancellationTokenSource]::new(-1)
                $responseMsg = $client.GetAsync([System.Uri]::new($Url), $cancelTokenSource.Token)
                $responseMsg.Wait()

                Write-Host "[http.client.handler] Downloading: $Url"

                if (!$responseMsg.IsCanceled) {
                    $response = $responseMsg.Result
                    if ($response.IsSuccessStatusCode) {
                        $downloadedFileStream = [System.IO.FileStream]::new(
                            $FilePathOut,
                            [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

                        $copyStreamOp = $response.Content.CopyToAsync($downloadedFileStream)

                        Write-Host "Download started..."
                        $copyStreamOp.Wait()

                        $downloadedFileStream.Close()
                        if ($null -ne $copyStreamOp.Exception) {
                            throw $copyStreamOp.Exception
                        }
                    }
                }
            }
            catch {
                Write-Host "[web.request] Downloading: $Url"
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -UseBasicParsing -Uri "$Url" -OutFile "$FilePathOut"
            }
        }
        finally {
            if (Test-Path -Path "$FilePathOut" -PathType Leaf) {
                Move-Item -Path "$FilePathOut" -Destination "$FilePath" -Force
                Write-Host "Downloaded file: '$FilePath'"
            }
            else {
                throw "⚠ Failed to download file: $Url"
            }
        }
    }
}

Function Get-TexLive {
    try {
        Write-Host "::group::Get TexLive"

        if ($IsWindows -or $ENV:OS) {
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
        }

        if ( -not(Test-Path -Path "$script:TempDir") ) {
            New-Item -ItemType directory -Path "$script:TempDir" | Out-Null
        }

        $tempTexFolder = "$script:TempDir/texlive-tmp"
        $tempTexTargetFolder = "$script:TempDir/texlive-install"
        $tempTexArchive = "$script:ArchivesDir/install-tl.zip"

        if (Test-Path -Path "$tempTexTargetFolder/install-tl-windows.bat" -PathType Leaf) {
            Write-Host "Installer already available: '$tempTexTargetFolder/install-tl-windows.bat'"
        }
        else {
            Get-File -Url "https://mirror.ctan.org/systems/texlive/tlnet/install-tl.zip" -Filename "$tempTexArchive"

            # Remove tex folder if it exists
            If (Test-Path "$tempTexFolder" -PathType Any) {
                Remove-Item -Recurse -Force "$tempTexFolder" | Out-Null
            }
            Expand-File -Path "$tempTexArchive" -DestinationPath "$tempTexFolder"

            Get-ChildItem -Path "$tempTexFolder" -Force -Directory | Select-Object -First 1 | Move-Item -Destination "$tempTexTargetFolder" -Force
        }

        # Remove tex folder if it exists
        If (Test-Path "$tempTexFolder" -PathType Any) {
            Remove-Item -Recurse -Force "$tempTexFolder" | Out-Null
        }

        $env:TEXLIVE_ROOT = "$script:TempDir/texlive-install"
        $env:TEXLIVE_INSTALL = "$env:TEXLIVE_ROOT/install-tl-windows.bat"

        $env:TEXDIR = "$script:TempDir/texlive"
        $env:TEXLIVE_BIN = "$env:TEXDIR/bin/win32"
        $env:TEXMFCONFIG = "$env:TEXDIR/texmf-config"
        $env:TEXMFHOME = "$env:TEXDIR/texmf-local"
        $env:TEXMFLOCAL = "$env:TEXDIR/texmf-local"
        $env:TEXMFSYSCONFIG = "$env:TEXDIR/texmf-config"
        $env:TEXMFSYSVAR = "$env:TEXDIR/texmf-var"
        $env:TEXMFVAR = "$env:TEXDIR/texmf-var"

        $env:TEXLIVE_INSTALL_PREFIX = "$env:TEXDIR"
        $env:TEXLIVE_INSTALL_TEXDIR = "$env:TEXDIR"
        $env:TEXLIVE_INSTALL_TEXMFCONFIG = "$env:TEXDIR/texmf-config"
        $env:TEXLIVE_INSTALL_TEXMFHOME = "$env:TEXDIR/texmf-local"
        $env:TEXLIVE_INSTALL_TEXMFLOCAL = "$env:TEXDIR/texmf-local"
        $env:TEXLIVE_INSTALL_TEXMFSYSCONFIG = "$env:TEXDIR/texmf-config"
        $env:TEXLIVE_INSTALL_TEXMFSYSVAR = "$env:TEXDIR/texmf-var"
        $env:TEXLIVE_INSTALL_TEXMFVAR = "$env:TEXDIR/texmf-var"

        $texLiveProfile = "$script:TempDir/install-texlive.profile"

        Set-Content -Path "$texLiveProfile" -Value @"
# It will NOT be updated and reflects only the
# installation profile at installation time.

selected_scheme scheme-custom
binary_win32 1
collection-basic 1
collection-wintools 1
collection-binextra 0
collection-formatsextra 0
instopt_adjustpath 0
instopt_adjustrepo 1
#instopt_desktop_integration 0
#instopt_file_assocs 0
instopt_letter 0
instopt_portable 1
instopt_write18_restricted 1
tlpdbopt_autobackup 1
tlpdbopt_backupdir tlpkg/backups
tlpdbopt_create_formats 1
tlpdbopt_desktop_integration 0
tlpdbopt_file_assocs 0
tlpdbopt_generate_updmap 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
tlpdbopt_post_code 1
tlpdbopt_sys_bin /usr/local/bin
tlpdbopt_sys_info /usr/local/share/info
tlpdbopt_sys_man /usr/local/share/man
tlpdbopt_w32_multi_user 0
"@

        If (Test-Path "$env:TEXLIVE_BIN/tex.exe" -PathType Leaf) {
            Write-Host "Skipped install. Tex executable already exists: '$env:TEXLIVE_BIN/tex.exe'"
        } elseif ($IsWindows -or $ENV:OS) {
            & cmd.exe /d /c "$env:TEXLIVE_INSTALL" -no-gui -portable -profile "$texLiveProfile"
        } else {
            Write-Host "TeX Live install process only supported on Windows."
        }
    }
    catch [Exception] {
        Write-Host "Failed to download and extract TeX Live.", $_.Exception.Message
    }
    finally {
        Write-Host "::endgroup::"
    }
}

Function Start-Bash() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param()

    Write-Host "bash -c '$Args'"

    if ($IsWindows -or $ENV:OS) {
        & "$script:MsysTargetDir/usr/bin/bash.exe" @('--noprofile', '--norc', '-lc') + @Args
    } else {
        Write-Host "Skipped command. This is only supported on Windows."
    }
}

Function Install-MSYS2 {
    $script:MsysTargetDir = "$script:TempDir/msys64"
    $script:MsysArchive = "$script:ArchivesDir/msys2.exe"

    if ( -not(Test-Path -Path "$script:MsysTargetDir/mingw64.exe" -PathType Leaf) ) {
        $msysInstaller = "https://github.com/msys2/msys2-installer/releases/download/2021-07-25/msys2-base-x86_64-20210725.sfx.exe"

        if ( -not(Test-Path -Path "$script:MsysArchive" -PathType Leaf) ) {
            Write-Host "::group::Download MSYS2"
            Get-File -Url "$msysInstaller" -Filename "$script:MsysArchive"
            Write-Host "::endgroup::"
        }

        if ( -not(Test-Path -Path "$script:MsysTargetDir/usr/bin/bash.exe" -PathType Leaf) ) {
            Write-Host "::group::Install MSYS2"
            Expand-File -Path "$script:MsysArchive" -Destination "$script:TempDir"
            Write-Host "::endgroup::"
        }
    }

    if (Test-Path -Path "$script:MsysTargetDir/usr/bin/bash.exe" -PathType Leaf) {
        $postInstallScript = "$script:MsysTargetDir/etc/post-install/09-stow.post"

        # Create a file that gets automatically called after installation which will silence the
        # clear that happens during a normal install. This may be useful for users by default but
        # this makes us lose the rest of the console log which is not great for our use case here.
        Set-Content -Path "$postInstallScript" -Value @"
MAYBE_FIRST_START=false
[ -f '/usr/bin/update-ca-trust' ] && sh /usr/bin/update-ca-trust
echo '[stow] Post-install complete.'
"@

        if ($IsWindows -or $ENV:OS) {
            # We run this here to ensure that the first run of msys2 is done before the 'setup.sh' call
            # as the initial upgrade of msys2 results in it shutting down the console.
            Write-Host "::group::Initialize MSYS2 Package Manager"
            Start-Bash "echo 'Validate that shell can print data.'"
            $msys2_shell = "$script:MsysTargetDir/msys2_shell.cmd"
            $msys2_shell += " -mingw64 -defterm -no-start -where $script:StowRoot -shell bash"
            $msys2_shell += " -c ./tools/install-dependencies.sh"
            & "cmd.exe" /d /s /c "$msys2_shell"
            Remove-Item -Force "$postInstallScript" | Out-Null
            Write-Host "::endgroup::"

            Write-Host "::group::Upgrade MSYS2 Packages"
            # Upgrade all packages
            Start-Bash 'pacman --noconfirm -Syuu'

            # Clean entire package cache
            Start-Bash 'pacman --noconfirm -Scc'
            Write-Host "::endgroup::"
        }

        Write-Host '[stow] Finished MSYS2 install.'
    }
}
Function Install-Toolset {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $script:StowRoot = Resolve-Path -Path "$PSScriptRoot/.."

    $env:HOME = $script:StowRoot

    $script:TempDir = Join-Path -Path "$script:StowRoot" -ChildPath ".tmp"
    if ( -not(Test-Path -Path "$script:TempDir") ) {
        New-Item -ItemType directory -Path "$script:TempDir" | Out-Null
    }

    $script:ArchivesDir = Join-Path -Path "$script:TempDir" -ChildPath "archives"
    if ( -not(Test-Path -Path "$script:ArchivesDir") ) {
        New-Item -ItemType directory -Path "$script:ArchivesDir" | Out-Null
    }

    Install-MSYS2

    Get-TexLive
}

Install-Toolset
