$InformationPreference = 'Continue'



function Get-LauncherVersion() {
    $params = @{
        Uri    = 'https://raw.githubusercontent.com/borkdude/deps.clj/master/resources/DEPS_CLJ_RELEASED_VERSION'
        Method = 'Get'
    }
    return $(Invoke-RestMethod @params).Trim()
}

function Get-RuntimeVersion() {
    $params = @{
        Uri     = 'https://api.github.com/repos/clojure/homebrew-tools/commits?author=clojure-build'
        Headers = @{Accept = 'application/vnd.github+json' }
        Method  = 'Get'
    }
    # lol
    $(Invoke-RestMethod @params).Where({ $PSItem.commit.message.StartsWith('Promote') }, 'First', 1).commit.message.Split()[1]
}

function Expand-WebArchive {
    param(
        [string] $Uri,
        [string] $Destination,
        [switch] $Overwrite
    )

    Write-Verbose "Extracting $Uri to $Destination"
    [System.IO.Compression.ZipFileExtensions]::ExtractToDirectory(
        [System.IO.Compression.ZipArchive]::new(
            [System.IO.MemoryStream]::new(
                ([System.Net.WebClient]::new()).DownloadData($Uri)
            )), 
        $Destination,
        $true
    )
}
function Copy-Launcher {
    param(
        [string] $Version = $(Get-LauncherVersion),
        [string] $Destination = $(Get-Location).Path
    )

    $params = @{
        Uri         = "https://github.com/borkdude/deps.clj/releases/download/v$Version/deps.clj-$Version-windows-amd64.zip"
        Destination = $Destination
        Overwrite   = $true
    }
    Write-Information "Downloading deps.exe version $Version"
    Expand-WebArchive @params
}

function Copy-Runtime {
    param(
        [string] $Version = $(Get-RuntimeVersion),
        [string] $Destination = $(Get-Location).Path
    )

    $params = @{
        Uri         = "https://download.clojure.org/install/clojure-tools-$Version.zip"
        Destination = $Destination
        Overwrite   = $true
    }
    Write-Information "Downloading runtime version $Version"
    Expand-WebArchive @params
    Move-Item -Path "$Destination\ClojureTools\*" -Destination $Destination -Force
    Remove-Item -Path "$Destination\ClojureTools"
}

function Copy-WixBinaries {
    param(
        [string] $Destination = $(Get-Location).Path
    )
        
    $params = @{
        Uri    = 'https://api.github.com/repos/wixtoolset/wix3/releases'
        Method = 'Get'
    }
    $params = @{
        Uri         = $(Invoke-RestMethod @params). `
            Where({ $PSItem.tag_name.EndsWith('rtm') }, 'First', 1). `
            assets. `
            Where({ $PSItem.name.EndsWith('binaries.zip') }). `
            browser_download_url
        Destination = $Destination
        Overwrite   = $true
    }
    Write-Information "Downloading WiX binaries"
    Expand-WebArchive @params
}

Remove-Item -Path files, out -Force -Recurse -ErrorAction SilentlyContinue

$launcherVersion = Get-LauncherVersion
$runtimeVersion = Get-RuntimeVersion

$params = @{
    Version     = $launcherVersion
    Destination = "files"
}
Copy-Launcher @params

$params = @{
    Version     = $runtimeVersion
    Destination = "files"
}
Copy-Runtime @params

if (-not $(Test-Path -Path wix_bin)) {
    Copy-WixBinaries -Destination wix_bin
}

Write-Information "Creating new MSI at $(Get-Location | Join-Path -ChildPath "out\clojure-$runtimeVersion.msi")"
.\wix_bin\candle.exe .\installers\combined.wxs -o out\combined.wixobj -nologo
.\wix_bin\light.exe -b .\files "-dRuntimeVersion=$runtimeVersion" "-dLauncherVersion=$launcherVersion" out\combined.wixobj -o "out\clojure-$runtimeVersion.msi" -spdb -dcl:high -nologo
Write-Information "Done"