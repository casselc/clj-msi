param([string] $WixDirectory = 'wix_bin', [string] $DownloadDirectory = 'files', [string] $WorkDirectory = 'work', [switch] $OnlyBuild) 

$InformationPreference = 'Continue'
[Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath



function Get-LauncherVersion() {
    $params = @{
        Uri    = 'https://raw.githubusercontent.com/borkdude/deps.clj/master/resources/DEPS_CLJ_RELEASED_VERSION'
        Method = 'Get'
    }
    return $(Invoke-RestMethod @params).Trim()
}

function Get-RuntimeVersion() {
    $params = @{
        Uri    = 'https://download.clojure.org/install/stable.properties'
        Method = 'Get'
    }
    $(Invoke-RestMethod @params).Split()[0]
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
        [string] $Destination = $(Get-Location -PSProvider FileSystem).ProviderPath
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
        [string] $Destination = $(Get-Location -PSProvider FileSystem).ProviderPath
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
        [string] $Destination = $(Get-Location -PSProvider FileSystem).ProviderPath
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

$launcherVersion = Get-LauncherVersion
$runtimeVersion = Get-RuntimeVersion
$packageVersion = $runtimeVersion.Substring(2)

if (-not $OnlyBuild) {
    Remove-Item -Path $DownloadDirectory -Force -Recurse -ErrorAction SilentlyContinue

    $params = @{
        Version     = $launcherVersion
        Destination = $DownloadDirectory
    }
    Copy-Launcher @params

    $params = @{
        Version     = $runtimeVersion
        Destination = $DownloadDirectory
    }
    Copy-Runtime @params

    if (-not $(Test-Path -Path $WixDirectory)) {
        Copy-WixBinaries -Destination $WixDirectory
    }
}

Write-Information "Creating new MSI at $(Join-Path -Path $(Get-Location -PSProvider FileSystem).ProviderPath -ChildPath "clojure-$packageVersion.msi")"
.\wix_bin\candle.exe .\installers\combined-permachine.wxs -o "$WorkDirectory\clojure.wixobj" -nologo
.\wix_bin\light.exe -b files -b resources -ext WixUIExtension "-cultures:en-us" "-dRuntimeVersion=$runtimeVersion" "-dPackageVersion=$packageVersion" "$WorkDirectory\clojure.wixobj" -o "clojure-$runtimeVersion.msi" -spdb -dcl:high -nologo
Write-Information "Done"