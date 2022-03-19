# Powershell Notes

Usefull Powershell commands

## Basic Check

Version 12.5.0 of PowerCLI has a bug on MacOS that will break these scripts. Here's how to check to
see if it gets fixed:

```powershell
Connect-VIServer
Get-VsanClusterConfiguration
Disconnect-VIServer
```

Connect to any vCenter. If the second command works, you are good to go.

## Install PowerCLI

```powershell
Install-Module -Name VMware.PowerCLI
```

## Update PowerCLI

```powershell
Update-Module -Name VMware.PowerCLI
```

## Display PowerCLI Version

```powershell
Get-Module -Name VMware.* | Select-Object -Property Name,Version
```

## Alow Self-Signed Certificates

Homelab servers typically do not have valid certificates. This will allow powershell to
interact with these servers:

```powershell
Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore
```

