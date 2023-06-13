# How to build the MSI locally

**Note: this information may be out of date. See the ci.ps1 script for a definitely working process.**

Clone this repository, open the repository root in a PowerShell terminal and run `.\build-clojure-msi.ps1`

The compiled package will be located in the current directory as `clojure-<currentclojureversion>.msi`

You can use the following additional options:
```
.\build-clojure-msi.ps1 -DownloadDirectory downloadpath` 
```
Set the location used for downloading Clojure binaries to build the installer. Default: `files` sub-folder of the current directory

```
.\build-clojure-msi.ps1 -WixDirectory wixpath` 
```
Set the location used for downloading WiX binaries to build the installer. Default: `wix_bin` sub-folder of the current directory

```
.\build-clojure-msi.ps1 -OnlyBuild` 
```
Rebuild the MSI package without downloading any files.