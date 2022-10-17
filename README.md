# Clojure Installer

This repo contains a script to build a proof-of-concept MSI package for installing Clojure. It downloads the latest version of deps.exe, ClojureTools, and WiX automatically and creates a combined installer file. The installer currently only supports a per-user unelevated installation.

## How to run

Run `build-clojure-msi.ps1` in a PowerShell terminal

The compiled package will be located at `out\clojure-<currentclojureversion>.msi`

## How to install

Double-click the resulting MSI file, or run `msiexec.exe /i out\clojure-x.x.xx.msi` from a command prompt or PowerShell session. In PowerShell, be careful of the shell automatically changing the path from `out\clojure-x.x.xxx.msi` to `.\out\clojure-x.x.xxx.msi`, the latter format will cause `msiexec` to throw an error.

Currently the installer installs to `%LOCALAPPDATA%\clojure` and no UI is provided to change the location. You can manually specify an alternate location at the commandline `msiexec.exe /i out\clojure-x.x.xxx.msi TARGETDIR=C:\somewhere\else`

## How to uninstall

Use Add/Remove Programs, or `msiexec.exe /x clojure-x.x.xxx.msi`