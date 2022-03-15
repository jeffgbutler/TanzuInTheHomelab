# Install TKGs with Tanzu Service Installer

Instructions for installing vSphere with Tanzu (TKGs) with NSX Advanced Load Balancer (AVI) in a nested homelab environment.

This nested environment is created in two steps:

1. Run a Powershell script to create a nested vCenter. The nested vCenter has these attributes:
   - 3 nested ESXi Hosts
   - 2 Portgroups mapped to VLANs in the outer vCenter
   - A Shared VSAN data store
   - A Content library containing the AVI controller OVA
1. Use the Tanzu Service Installer (a.k.a. Arcas) to enable and configure TKGs in the nested vCenter

## Prerequisites

### Downloads

1. ESXi
   - Download the latest nested ESXi appliance from WIlliam Lam: https://williamlam.com/nested-virtualization/nested-esxi-virtual-appliance
   - Update the `$NestedESXiApplianceOVA` script variable with the location of the downloaded OVA
1. vCenter
   - Download the vCenter server appliance ISO from my.vmware.com or buildweb.vmware.com (internal)
   - Mount the ISO and copy all files/directories into a directory on your disk
   - Update the `$VCSAInstallerPath` script variable with the location of the directory
   - If you are on a Mac, disable gatekeeper with a command similar to the following:
     `sudo xattr -r -d com.apple.quarantine VMware-VCSA-all-7.0.3-19234570`
1. NSX Advanced LoadBalancer (aka AVI Vantage)
   - Download NSX ALB from https://portal.avipulse.vmware.com/software/vantage
   - Update the `$NSXAdvLBOVA` script variable with the location of the downloaded OVA


### DNS Entries

| Name                         | Address         |
|------------------------------|-----------------|
| vcsa.tkgs.tanzuathome.net    | 192.168.138.3   |
| esxi-1.tkgs.tanzuathome.net  | 192.168.138.4   |
| esxi-2.tkgs.tanzuathome.net  | 192.168.138.5   |
| esxi-3.tkgs.tanzuathome.net  | 192.168.138.6   |
| nsx-alb.tkgs.tanzuathome.net | 192.168.138.9   |

## Procedure

1. Run the script `nestedEsxiForTKGs.ps1`. This will create a new vCenter with three nested ESXi hosts.
   The script will run for approximately 40 minutes.
1. Login to the new vCenter (https://vcsa.tkgs.tanzuathome.net/ui) (administrator@vsphere.local/VMware1!)
1. SSH into the Service Installer VM (ssh root@192.168.128.23) password is: TaB5!@9Y

arcas --env vsphere --file tkgs.json --avi_configuration \
  --avi_wcp_configuration --enable_wcp --create_supervisor_namespace \
  --create_workload_cluster

## Resources

Vault page: https://vault.vmware.com/group/vault-main-library/service-installer-for-vmware-tanzu

Arcas FAQ: https://vault.vmware.com/group/vault-main-library/document-preview/-/document_library/6KC5yhh3TpWl/view_file/72967477

## Troubleshooting

Important: the VCenter install will fail if you are on the VMware VPN!

Arcas Logging is in the Arcas VM at /var/log/server
