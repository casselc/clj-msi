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

function Get-LatestRelease {
    [CmdletBinding()]
    param (
        [string] $Repository
    )
    
    Invoke-GithubAPI -RelativeUri "repos/$Repository/releases/latest"
}

function Get-PackageVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]
        $ClojureVersion,
        [Parameter(Mandatory)]
        $DepsRelease
    )

    $week_start = $DepsRelease.created_at.AddDays(-$DepsRelease.created_at.DayOfWeek.value__)
    $week_start = Get-Date -Year $week_start.Year -Month $week_start.Month -Day $week_start.Day -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC
    $mins = [int] ($DepsRelease.created_at - $week_start).TotalMinutes
    $cal = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    $week = $cal.GetWeekOfYear($DepsRelease.created_at, 'FirstDay', 'Sunday')
    $year = $DepsRelease.created_at.Year - 2000
    $patch = $ClojureVersion.Split('.')[-1]

    "$year.$week.$mins.$patch"
}


$latest_deps = Get-LatestRelease -Repository 'borkdude/deps.clj'
$latest_msi = Get-LatestRelease -Repository 'casselc/clj-msi'

if (($latest_deps.tag_name -ne $latest_msi.tag_name) -and ($latest_msi.created_at -lt $latest_deps.created_at)) {
    $tag = $latest_deps.tag_name

    Write-Host "Building new MSI for $tag"

    if (-not $(Test-Path -Path wix_bin)) {
        $latest_wix = Get-LatestRelease -Repository 'wixtoolset/wix3'
        $wix_url = $latest_wix.assets.Where({ $PSItem.name.EndsWith('binaries.zip') }, 'First', 1).browser_download_url
        Write-Information "Downloading WiX binaries"
        Expand-WebArchive -Uri $wix_url -Destination wix_bin 
    }

    $deps_url = $latest_deps.assets.Where({ $PSItem.name.Contains('windows') -and $PSItem.content_type.Contains('zip') }, 'First', 1).browser_download_url
    Write-Information "Downloading deps.exe"
    Expand-WebArchive -Uri $deps_url -Destination files -Overwrite

    $clojure_version, $clojure_hash, $_line = $(Invoke-RestMethod -Uri 'https://download.clojure.org/install/stable.properties').Split()
    $clojure_url = "https://download.clojure.org/install/clojure-tools-$clojure_version.zip"
    Write-Information "Downloading ClojureTools"
    Expand-WebArchive -Uri $clojure_url -Destination files -Overwrite
    Move-Item -Path files\ClojureTools\* -Destination files -Force
    Remove-Item -Path files\ClojureTools

    $package_version = Get-PackageVersion -DepsRelease $latest_deps -ClojureVersion $clojure_version
    $filename = "clojure-$clojure_version.msi"

    .\wix_bin\candle.exe installers\clojure.wxs -nologo
    .\wix_bin\light.exe -b files -b resources -ext WixUIExtension "-cultures:en-us" "-dClojureVersion=$clojure_version" "-dPackageVersion=$package_version" clojure.wixobj -o $filename -spdb -dcl:high -nologo

    if ($env:GITHUB_REPOSITORY) {
        Write-Information "Creating new release with tag $tag"
        $body = "Automated build of Windows Installer package for Clojure. This release includes the following components:`n- [deps.clj $tag]($($latest_deps.url))`n - [Clojure Tools $clojure_version]($clojure_url)"

        $release = Invoke-GithubAPI -Method Post -RelativeUri "/repos/$env:GITHUB_REPOSITORY/releases" -Body @{tag_name = $Tag ; name = "Clojure $clojure_version"; body = $body; prerelease = $false; draft = $true }
        $uploadUri = $release.upload_url -replace '\{.*\}', ''
        $uploadUri += "?name=$filename"

        Write-Information "Uploading $filename as asset"
        $(Invoke-GithubAPI -Method Post -RelativeUri $uploadUri -InFile $filename -ContentType 'application/x-msi').browser_download_url
    }
} else {
    Write-Information "Up to date, nothing to do."
}
