# Clojure Installer

This repo contains a script to build a proof-of-concept MSI package for installing Clojure. It downloads the latest version of [deps.exe](https://github.com/borkdude/deps.clj), [ClojureTools](https://github.com/clojure/brew-install), and the [WiX toolset](https://wixtoolset.org/releases/) automatically and creates a combined installer file. The installer supports per-user or per-machine (requires elevation) installation.

## How to build the MSI locally

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



## How to install the MSI 

Double-click the resulting MSI file, or run `msiexec.exe /i clojure-x.x.xx.msi` from a command prompt or PowerShell session, or `msiexec.exe /i clojure-x.x.xx.msi /qn` for a silent installation. In PowerShell, be careful of the shell automatically changing the path from `clojure-x.x.xxx.msi` to `.\clojure-x.x.xxx.msi`, the latter format will cause `msiexec` to throw an error.

Currently the installer defaults to `%LOCALAPPDATA%\Apps\clojure` or `%ProgramFiles%\clojure` depending on whether you select a per-user or per-machine installation, and the installation directory can be changed by using the Advanced option during installation, or at the command line by settingsthe `APPLICATIONFOLDER` property, e.g. `msiexec.exe /i clojure-x.x.xx.msi /qn APPLICATIONFOLDER=C:\somewhere\else\clojure`

## How to uninstall

Use Add/Remove Programs, or `msiexec.exe /x clojure-x.x.xxx.msi`