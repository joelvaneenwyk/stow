<#
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

    $7za920zip = "$script:TempDir\7za920.zip"
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
        $7z1900zip = "$script:TempDir\7z1900-extra.7z"
        $7z1900 = "$script:TempDir\7z1900"
        if (-not(Test-Path -Path "$7z1900zip" -PathType Leaf)) {
            Get-File -Url "https://www.7-zip.org/a/7z1900-extra.7z" -Filename "$7z1900zip"
        }
        if (Test-Path -Path "$7z1900zip" -PathType Leaf) {
            if (-not(Test-Path -Path "$7z1900\7za.exe" -PathType Leaf)) {
                & "$7za920\7za.exe" x "$7z1900zip" -aoa -o"$7z1900" -r -y | Out-Default
            }
        }
    }

    try {
        Write-Host "Extracting archive: '$Path'"
        if (Test-Path -Path "$7z1900\x64\7za.exe" -PathType Leaf) {
            & "$7z1900\x64\7za.exe" x "$Path" -aoa -o"$DestinationPath" -r -y | Out-Default
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

    $FilePath = $Filename

    # Make absolute local path
    if (![System.IO.Path]::IsPathRooted($Filename)) {
        $FilePath = Join-Path (Get-Item -Path ".\" -Verbose).FullName $Filename
    }


    $handler = $null
    $webclient = $null

    try {
        $webclient = New-Object System.Net.WebClient
    }
    catch {
        try {
            $handler = New-Object -TypeName System.Net.Http.HttpClientHandler
        }
        catch {
            $handler = $null
            $webclient = $null
        }
    }

    if ($null -ne ($Url -as [System.URI]).AbsoluteURI) {
        if ($null -ne $webclient) {
            Write-Host "Downloading with web client: $Url"
            $webclient.DownloadFile([System.Uri]::new($Url), "$Filename")
        }
        elseif ($null -ne $handler) {
            Write-Host "Downloading with client handler: $Url"
            $handler = New-Object -TypeName System.Net.Http.HttpClientHandler
            $client = New-Object -TypeName System.Net.Http.HttpClient -ArgumentList $handler
            $client.Timeout = New-Object -TypeName System.TimeSpan -ArgumentList 0, 30, 0
            $cancelTokenSource = [System.Threading.CancellationTokenSource]::new(-1)
            $responseMsg = $client.GetAsync([System.Uri]::new($Url), $cancelTokenSource.Token)
            $responseMsg.Wait()
            if (!$responseMsg.IsCanceled) {
                $response = $responseMsg.Result
                if ($response.IsSuccessStatusCode) {
                    $downloadedFileStream = [System.IO.FileStream]::new(
                        $FilePath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

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
        else {
            Write-Host "Downloading with invoke web request: $Url"
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -UseBasicParsing -Uri "$Url" -OutFile "$Filename"
        }

        Write-Host "Downloaded file: '$Filename'"
    }
    else {
        throw "⚠ Failed to download file: $Url"
    }
}

Function Get-TexLive {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

    $tempFolder = "$PSScriptRoot\..\.build"
    if ( -not(Test-Path -Path "$tempFolder") ) {
        New-Item -ItemType directory -Path "$tempFolder" | Out-Null
    }
    $tempFolder = Resolve-Path -Path "$tempFolder"

    try {
        $tempTexTargetFolder = "$tempFolder\texlive-install"
        if (Test-Path -Path "$tempTexTargetFolder\install-tl-windows.bat" -PathType Leaf) {
            Write-Host "Installer already available: '$tempTexTargetFolder\install-tl-windows.bat'"
        }
        else {
            $tempTexFolder = "$tempFolder\texlive-tmp"
            $tempTexArchive = "$tempFolder\install-tl.zip"

            if ( -not(Test-Path -Path "$tempTexArchive" -PathType Leaf) ) {
                $url = 'https://mirror.ctan.org/systems/texlive/tlnet/install-tl.zip'
                Start-BitsTransfer -Source $url -Destination $tempTexArchive
                Write-Host "Downloaded TeX Live archive: '$url'"
            }

            # Remove tex folder if it exists
            If (Test-Path "$tempTexFolder" -PathType Any) {
                Remove-Item -Recurse -Force "$tempTexFolder" | Out-Null
            }
            Expand-Archive "$tempTexArchive" -DestinationPath "$tempTexFolder" -Force

            Get-ChildItem -Path "$tempTexFolder" -Force -Directory | Select-Object -First 1 | Move-Item -Destination "$tempTexTargetFolder"

            Remove-Item -Recurse -Force "$tempTexFolder" | Out-Null
            Write-Host "Removed intermediate folder: '$tempTexFolder'"

            Remove-Item -Recurse -Force "$tempTexArchive" | Out-Null
            Write-Host "Removed intermediate archive: '$tempTexArchive'"
        }
    }
    catch [Exception] {
        Write-Host "Failed to download and extract TeX Live.", $_.Exception.Message
    }
}

Function Install-Toolset {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $script:StowRoot = Resolve-Path -Path "$PSScriptRoot\.."

    $script:TempDir = "$script:StowRoot\.tmp"
    if ( -not(Test-Path -Path "$script:TempDir") ) {
        New-Item -ItemType directory -Path "$script:TempDir" | Out-Null
    }

    $ezwinports = @(
        "https://sourceforge.net/projects/ezwinports/files/binutils-2.37-w32-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/texinfo-6.8-w32-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/make-4.3-without-guile-w32-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/autoconf-2.65-msys-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/automake-1.11.6-msys-bin.zip/download",
        "https://sourceforge.net/projects/ezwinports/files/which-2.20-2-w32-bin.zip/download",
        "https://github.com/git-for-windows/git/releases/download/v2.33.0.windows.2/PortableGit-2.33.0.2-64-bit.7z.exe"
    )

    foreach ($ezwinport in $ezwinports) {
        $filename = ([System.Uri]($ezwinport -replace "/download", "")).Segments[-1]
        $outPath = "$script:TempDir\$filename"
        Write-Host "::group::Install '$filename'"
        Get-File -Url $ezwinport -Filename "$outPath"
        Expand-File -Path "$outPath" -DestinationPath "$script:TempDir\ezwinports"
        Write-Host "::endgroup::"
    }
}

Install-Toolset

# Not getting this yet as it may not be needed.
#Get-TexLive
