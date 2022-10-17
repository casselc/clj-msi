# Clojure Installer

This repo contains a script to build a proof-of-concept MSI package for installing Clojure. It downloads the latest version of deps.exe, ClojureTools, and WiX automatically and creates a combined installer file. The installer supports per-user or per-machine (requires elevation) installation.

## How to run

Run `build-clojure-msi.ps1` in a PowerShell terminal

The compiled package will be located at `out\clojure-<currentclojureversion>.msi`

## How to install

Double-click the resulting MSI file, or run `msiexec.exe /i out\clojure-x.x.xx.msi` from a command prompt or PowerShell session, or `msiexec.exe /i out\clojure-x.x.xx.msi /qn` for a silent installation. In PowerShell, be careful of the shell automatically changing the path from `out\clojure-x.x.xxx.msi` to `.\out\clojure-x.x.xxx.msi`, the latter format will cause `msiexec` to throw an error.

Currently the installer defaults to `%LOCALAPPDATA%\Apps\clojure` or `%ProgramFiles%\clojure` depending on whether you select a per-user or per-machine installation, and the installation directory can be changed by using the Advanced option during installation. 

## How to uninstall

Use Add/Remove Programs, or `msiexec.exe /x clojure-x.x.xxx.msi`