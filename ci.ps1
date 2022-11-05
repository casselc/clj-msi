$InformationPreference = 'Continue'
[Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath

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

function Get-ClojureVersion {
    $params = @{
        Uri    = 'https://download.clojure.org/install/stable.properties'
        Method = 'Get'
    }
    $(Invoke-RestMethod @params).Split()[0]
}

function Invoke-GithubAPI {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias('Uri')]
        [string]
        $RelativeUri,

        [string] $Method = 'Get',
        [hashtable] $Body,
        [string] $InFile,
        [string] $ContentType
    )

    $params = @{
        Method  = $Method
        Uri     = [uri]::new([uri]'https://api.github.com', $RelativeUri)
        Headers = @{Accept = 'application/vnd.github+json' }
    }

    if ($Body) {
        $params['Body'] = ConvertTo-Json -InputObject $Body
    }

    if ($InFile) {
        $params['InFile'] = $InFile
    }

    if ($ContentType) {
        $params['ContentType'] = $ContentType
    }
    
    if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
        $params['Authentication'] = 'Bearer'
        $params['Token'] = $(ConvertTo-SecureString -AsPlainText -Force -String $env:GH_TOKEN)
    }

    return $(Invoke-RestMethod @params)
}

function Copy-WixBinaries {
    param(
        [string] $Destination = $(Get-Location -PSProvider FileSystem).ProviderPath
    )
        
    $params = @{
        Uri         = $(Invoke-GithubAPI -RelativeUri 'repos/wixtoolset/wix3/releases'). `
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

function Get-ClojureTags {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $Latest
    )

    $tags = $(Invoke-GithubAPI -Uri '/repos/clojure/brew-install/tags').ForEach('name').Where({ $PSItem -imatch '^\d.+' })

    if ($Latest) {
        return $tags[0]
    }
    else {
        return $tags
    }

}

function Get-DepsTags {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $Latest
    )

    $tags = $(Invoke-GithubAPI -Uri '/repos/borkdude/deps.clj/tags').ForEach('name').Where({ $PSItem -imatch '^v\d.+' })

    if ($Latest) {
        return $tags[0]
    }
    else {
        return $tags
    }
}

function Get-MsiTags {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $Latest
    )

    $tags = $(Invoke-GithubAPI -Uri '/repos/casselc/clj-msi/tags').ForEach('name').Where({ $PSItem -imatch '^v?\d.+' })

    if ($Latest) {
        return $tags[0]
    }
    else {
        return $tags
    }
}
function Compare-LatestTags {
    $msiVersion = Get-MsiTags -Latest
    $cljVersion = Get-ClojureTags -Latest
    $stableVersion = Get-ClojureVersion
    $depsVersion = Get-DepsTags -Latest

    return  [PSCustomObject]@{
        MSI        = $msiVersion
        Clojure    = $cljVersion
        Deps       = $depsVersion
        UpToDate   = ($msiVersion.TrimStart('v') -eq $cljVersion)
        Prerelease = ($stableVersion -ne $cljVersion)
    } 
}

function Build-ClojureMSI {
    [CmdletBinding()]
    param (
        [string] $ClojureVersion = $(Get-ClojureTags -Latest),
        [string] $DepsVersion = $(Get-DepsTags -Latest),
        [switch] $Publish,
        [switch] $Prerelease

    )
    if (-not $(Test-Path -Path wix_bin)) {
        Copy-WixBinaries -Destination wix_bin
    }

    $packageVersion = $clojureVersion.Split('.', 2)[1]
    $filename = "clojure-$clojureVersion.msi"

    Copy-DepsRelease -VersionTag $DepsVersion -Destination files
    Copy-ClojureTools -Version $ClojureVersion -Destination files 

    .\wix_bin\candle.exe installers\clojure.wxs -nologo
    .\wix_bin\light.exe -b files -b resources -ext WixUIExtension "-cultures:en-us" "-dClojureVersion=$clojureVersion" "-dPackageVersion=$packageVersion" clojure.wixobj -o $filename -spdb -dcl:high -nologo

    if ($Publish) {
        Publish-ClojureMSI -Path $filename -Version $ClojureVersion -Prerelease:$Prerelease
    }
}

function Publish-ClojureMSI {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Path,
        [string] $Version,
        [switch] $Prerelease
    )
    $tag = "v$Version"
    Write-Information "Checking for existing release with tag $tag"
    $release = Invoke-GithubAPI -RelativeUri "/repos/casselc/clj-msi/releases/tags/$tag" -ErrorAction SilentlyContinue -ErrorVariable ghError

    if ($ghError) {
        Write-Error $ghError
        Exit 1
    }

    if (-not $release) {
        $release = Invoke-GithubAPI -Method Post -RelativeUri '/repos/casselc/clj-msi/releases' -Body @{tag_name = $tag ; name = "Clojure $Version"; body = "Automated build of Windows Installer package for Clojure version $Version"; prerelease = $Prerelease.ToBool(); draft = $true }
    }


    
    $uploadUri = $release.upload_url -replace '\{.*\}', ''
    $uploadUri += "?name=$(Split-Path -Path $Path -Leaf)"

    Write-Information "Uploading $Path as asset"
    return $(Invoke-GithubAPI -Method Post -RelativeUri $uploadUri -InFile $Path -ContentType 'application/x-msi').browser_download_url
}

function Copy-DepsRelease {
    [CmdletBinding()]
    param (
        [Alias('Version')]
        [string] $VersionTag = $(Get-DepsTags -Latest),
        [string] $Destination = (Get-Location -PSProvider FileSystem).ProviderPath
    )
    $download_url = $(Invoke-GithubAPI -RelativeUri "/repos/borkdude/deps.clj/releases/tags/$VersionTag").assets.Where({ $PSItem.name.Contains('windows') }, 'First', 1).ForEach('browser_download_url')[0]
    
    Write-Information "Downloading deps.exe version $VersionTag"
    Expand-WebArchive -Uri $download_url -Destination $Destination -Overwrite 
}

function Copy-ClojureTools {
    param(
        [string] $Version = $(Get-ClojureTags -Latest),
        [string] $Destination = $(Get-Location -PSProvider FileSystem).ProviderPath
    )

    $params = @{
        Uri         = "https://download.clojure.org/install/clojure-tools-$Version.zip"
        Destination = $Destination
        Overwrite   = $true
    }
    Write-Information "Downloading ClojureTools version $Version"
    Expand-WebArchive @params
    Move-Item -Path "$Destination\ClojureTools\*" -Destination $Destination -Force
    Remove-Item -Path "$Destination\ClojureTools"
}

function Update-ClojureMSI {
    $status = Compare-LatestTags
    if (-not $status.UpToDate) {
        $tags = @(Get-MsiTags).Where({ $PSItem -match "v?$($status.Clojure)" }, 'First', 1)
        if ($tags.Count -eq 0) {
            Build-ClojureMSI -Publish
            
        }
        else {
            Write-Information "Found matching pre-existing tag"
        }
    }
    else {
        Write-Information "Most recent version has already been published"
    }
}
