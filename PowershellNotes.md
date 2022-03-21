# Powershell Notes

Scripts in this repository use Powershell and the VMware PowerCLI plugin. More information
about PowerCLI is here: https://developer.vmware.com/powercli


## Basic Check

Version 12.5.0 of PowerCLI has a bug on MacOS that will break these scripts. Here's how to check to
see if it gets fixed:

```powershell
Connect-VIServer
Get-VsanClusterConfiguration
Disconnect-VIServer
```

Connect to any vCenter. If the second command works, you are good to go.

## Display All Available Versions

```powershell
Find-Module -Name VMware.PowerCLI -AllVersions
```

## Install PowerCLI

Install the latest version:

```powershell
Install-Module -Name VMware.PowerCLI
```

Install a specific version:

```powershell
Install-Module -Name VMware.PowerCLI -RequiredVersion 12.0.0.15947286
```

## Update PowerCLI

```powershell
Update-Module -Name VMware.PowerCLI
```

## Uninstall PowerCLI

```powershell
Get-Module VMware.* -ListAvailable | Uninstall-Module -Force
```

## Display PowerCLI Version

```powershell
Get-Module -Name VMware.* -ListAvailable | Select-Object -Property Name,Version
```

## Alow Self-Signed Certificates

Homelab servers typically do not have valid certificates. This will allow PowerCLI to
interact with these servers:

```powershell
Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore
```

