﻿<#
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
        $DestinationPath = Join-Path (Get-Item -Path ".\" -Verbose).FullName $DestinationPath
    }

    if (![System.IO.Path]::IsPathRooted($Path)) {
        $Path = Join-Path (Get-Item -Path ".\" -Verbose).FullName $Path
    }

    $7za920zip = "$script:ArchivesDir\7za920.zip"
    $7za920 = "$script:TempDir\7za920"
    if (-not(Test-Path -Path "$7za920zip" -PathType Leaf)) {
        Get-File -Url "https://www.7-zip.org/a/7za920.zip" -Filename "$7za920zip"
    }
    if (Test-Path -Path "$7za920zip" -PathType Leaf) {
        if (-not(Test-Path -Path "$7za920\7za.exe" -PathType Leaf)) {
            $ProgressPreference = 'SilentlyContinue'
            Expand-Archive -Path "$7za920zip" -DestinationPath "$7za920"
        }
    }

    if (Test-Path -Path "$7za920\7za.exe" -PathType Leaf) {
        $7z2103zip = "$script:ArchivesDir\7z2103-extra.7z"
        $7z2103 = "$script:TempDir\7z2103"
        if (-not(Test-Path -Path "$7z2103zip" -PathType Leaf)) {
            Get-File -Url "https://www.7-zip.org/a/7z2103-extra.7z" -Filename "$7z2103zip"
        }
        if (Test-Path -Path "$7z2103zip" -PathType Leaf) {
            if (-not(Test-Path -Path "$7z2103\7za.exe" -PathType Leaf)) {
                & "$7za920\7za.exe" x "$7z2103zip" -aoa -o"$7z2103" -r -y | Out-Default
            }
        }
    }

    try {
        Write-Host "Extracting archive: '$Path'"
        if (Test-Path -Path "$7z2103\x64\7za.exe" -PathType Leaf) {
            & "$7z2103\x64\7za.exe" x "$Path" -aoa -o"$DestinationPath" -r -y | Out-Default
        }
        elseif (Test-Path -Path "$7za920\7za.exe" -PathType Leaf) {
            & "$7za920\7za.exe" x "$Path" -aoa -o"$DestinationPath" -r -y | Out-Default
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
        $FilePath = Join-Path (Get-Item -Path ".\" -Verbose).FullName $Filename
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

        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

        if ( -not(Test-Path -Path "$script:TempDir") ) {
            New-Item -ItemType directory -Path "$script:TempDir" | Out-Null
        }

        $tempTexTargetFolder = "$script:TempDir\texlive-install"
        $tempTexFolder = "$script:TempDir\texlive-tmp"
        $tempTexArchive = "$script:ArchivesDir\install-tl.zip"

        if (Test-Path -Path "$tempTexTargetFolder\install-tl-windows.bat" -PathType Leaf) {
            Write-Host "Installer already available: '$tempTexTargetFolder\install-tl-windows.bat'"
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
    & "$script:MsysTargetDir\usr\bin\bash.exe" @('--noprofile', '--norc', '-lc') + @Args
}

Function Install-MSYS2 {
    $script:MsysTargetDir = "$script:TempDir\msys64"
    $script:MsysArchive = "$script:ArchivesDir\msys2.exe"

    if ( -not(Test-Path -Path "$script:MsysTargetDir\mingw64.exe" -PathType Leaf) ) {
        $msysInstaller = "https://github.com/msys2/msys2-installer/releases/download/2021-07-25/msys2-base-x86_64-20210725.sfx.exe"

        if ( -not(Test-Path -Path "$script:MsysArchive" -PathType Leaf) ) {
            Write-Host "::group::Download MSYS2"
            Get-File -Url "$msysInstaller" -Filename "$script:MsysArchive"
            Write-Host "::endgroup::"
        }

        if ( -not(Test-Path -Path "$script:MsysTargetDir\usr\bin\bash.exe" -PathType Leaf) ) {
            Write-Host "::group::Install MSYS2"
            Expand-File -Path "$script:MsysArchive" -Destination "$script:TempDir"
            Write-Host "::endgroup::"
        }
    }

    if (Test-Path -Path "$script:MsysTargetDir\usr\bin\bash.exe" -PathType Leaf) {
        $postInstallScript = "$script:MsysTargetDir\etc\post-install\09-stow.post"

        # Create a file that gets automatically called after installation which will silence the
        # clear that happens during a normal install. This may be useful for users by default but
        # this makes us lose the rest of the console log which is not great for our use case here.
        Set-Content -Path "$postInstallScript" -Value @"
MAYBE_FIRST_START=false
[ -f '/usr/bin/update-ca-trust' ] && sh /usr/bin/update-ca-trust
echo '[stow] Post-install complete.'
"@

        # We run this here to ensure that the first run of msys2 is done before the 'setup.sh' call
        # as the initial upgrade of msys2 results in it shutting down the console.
        Write-Host "::group::Initialize MSYS2 Package Manager"
        Start-Bash "echo 'Validate that shell can print data.'"

        $msys2_shell = "$script:MsysTargetDir\msys2_shell.cmd"
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

        Write-Host '[stow] Finished MSYS2 install.'
    }
}

Function Install-UnixPorts {
    $git = "$script:TempDir\git"

    Write-Host "::group::Install Portable Git"
    $portableGitArchive = "$script:ArchivesDir\PortableGit-2.33.0.2-64-bit.7z.exe"
    Get-File -Url "https://github.com/git-for-windows/git/releases/download/v2.33.0.windows.2/PortableGit-2.33.0.2-64-bit.7z.exe" -Filename $portableGitArchive
    Expand-File -Path $portableGitArchive -DestinationPath "$git"
    Write-Host "::endgroup::"

    Write-Host "::group::Install 'm4'"
    foreach ($m4 in @(
        "http://downloads.sourceforge.net/gnuwin32/m4-1.4.14-1-bin.zip",
        "http://downloads.sourceforge.net/gnuwin32/m4-1.4.14-1-dep.zip"
    )) {
        $filename = ([System.Uri]$m4).Segments[-1]
        $outPath = "$script:ArchivesDir\$filename"
        Get-File -Url $m4 -Filename "$outPath"
        Expand-File -Path "$outPath" -DestinationPath "$git\usr"
    }
    Write-Host "::endgroup::"

    foreach ($ezwinport in @(
        "https://sourceforge.net/projects/ezwinports/files/binutils-2.37-w32-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/texinfo-6.8-w32-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/make-4.3-with-guile-w32-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/autoconf-2.65-msys-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/automake-1.11.6-msys-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/which-2.20-2-w32-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/guile-2.0.11-2-w32-bin.zip/download"
    )) {
        $filename = ([System.Uri]($ezwinport -replace "/download", "")).Segments[-1]
        $outPath = "$script:ArchivesDir\$filename"
        Write-Host "::group::Install '$filename'"
        Get-File -Url $ezwinport -Filename "$outPath"
        Expand-File -Path "$outPath" -DestinationPath "$script:TempDir\ezwinports"
        Write-Host "::endgroup::"
    }

    Write-Host "::group::Copy 'ezwinports' to 'git'"
    Copy-Item -Path "$script:TempDir\ezwinports\mingw32" -Destination "$git" -Force -Recurse
    Copy-Item -Path "$script:TempDir\ezwinports\bin" -Destination "$git\usr" -Force -Recurse
    Copy-Item -Path "$script:TempDir\ezwinports\include" -Destination "$git\usr" -Force -Recurse
    Copy-Item -Path "$script:TempDir\ezwinports\lib" -Destination "$git\usr" -Force -Recurse
    Copy-Item -Path "$script:TempDir\ezwinports\share" -Destination "$git\usr" -Force -Recurse
}
Function Install-Toolset {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $script:StowRoot = Resolve-Path -Path "$PSScriptRoot\.."

    $env:HOME = $script:StowRoot

    $script:TempDir = "$script:StowRoot\.tmp"
    if ( -not(Test-Path -Path "$script:TempDir") ) {
        New-Item -ItemType directory -Path "$script:TempDir" | Out-Null
    }

    $script:ArchivesDir = "$script:StowRoot\.tmp\archives"
    if ( -not(Test-Path -Path "$script:ArchivesDir") ) {
        New-Item -ItemType directory -Path "$script:ArchivesDir" | Out-Null
    }

    Install-MSYS2

    Get-TexLive
}

Install-Toolset
