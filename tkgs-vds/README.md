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

## Procedure Part 1: Nested Infrastructure

Run the script `nestedEsxiForTKGs.ps1`. This will create a new vCenter with three nested ESXi hosts.

There are a large set of variables at the beginning of this script that define the nested environment. The most
important of these are the IP addresses, domain names, and network names from the outer vCenter. The values in the script
are based on my home lab network. I am using two VLANs - `vm-network-138` and `vm-network-139` - with CIDRs `192.168.138.0/24`
 and `192.168.139.0/24` - respectively. In your environment you may need to change these values. You will also see multiple
 references to a domain `tanzuathome.net` that I own. You should change these values to match a domain that you control, and where
 you can manage DNS entries.

 Before running the script, you should create DNS entries to match entries in the script. In my environment, I use
 the following DNS records:

| Name                         | Address         |
|------------------------------|-----------------|
| vcsa.tkgs.tanzuathome.net    | 192.168.138.3   |
| esxi-1.tkgs.tanzuathome.net  | 192.168.138.4   |
| esxi-2.tkgs.tanzuathome.net  | 192.168.138.5   |
| esxi-3.tkgs.tanzuathome.net  | 192.168.138.6   |
| nsx-alb.tkgs.tanzuathome.net | 192.168.138.9   |

The script will run for approximately 40 minutes.

**Important:** the vCenter install will fail if you are on the VMware VPN!


## Procedure Part 2: Enable Kubernetes with Tanzu Service Installer

### Network Design

TKGs uses three types of networks - management, workload, and VIP networks. This installation is based on the
two network model for TKGs - where the workload and VIP networks share the same subnet. When designing
a Kubernetes environment it is also important to be mindful for the netowrks that exist inside a Kubernetes cluster - those
networks cannot overlap each other, and should not overlap with other networks in use.
The table below shows the network design for TKGs in my home lab:

| Network      | Item                         | IP or Range         |
|--------------|------------------------------|---------------------|
| Management   | vcsa.tkgs.tanzuathome.net    | 192.168.138.3       |
| Management   | esxi-1.tkgs.tanzuathome.net  | 192.168.138.4       |
| Management   | esxi-2.tkgs.tanzuathome.net  | 192.168.138.5       |
| Management   | esxi-3.tkgs.tanzuathome.net  | 192.168.138.6       |
| Management   | nsx-alb.tkgs.tanzuathome.net | 192.168.138.9       |
| Management   | NSX Service Engines          | 192.168.138.180-187 |
| Management   | Start of 5 Address Range     | 192.168.138.190     |
| VIP          | VIP Network Range            | 192.168.139.2-126   |
| Workload     | Workload Network Range       | 192.168.139.128-254 |
| K8S Internal | Supervisor Service CIDR      | 10.113.0.0/16       |
| K8S Internal | POD CIDR                     | 10.96.0.0/12        |
| K8S Internal | Service CIDR                 | 10.112.0.0/16       |




### Data Collector

When you run the service installer, you will need to supply many configuration variables. These are the same variables you will
need when installing TKGs in a customer environment - so you can think if the service installer as a "data collector" for
configuration variables you will need. These are the important configuration variables in use in my environment (not all variables
are listed below):

| Configuration Setting | Value | Notes |
|---|---|---|
| **Infrastructure Section** |
| DNS | 192.168.128.1 | DNS in my network |
| DNS Search Domain | tkgs.tanzuathome.net |  |
| NTP Servers | pool.ntp.org |  |
| **IaaS Provider Section** |
| Download NSX ALB | Off | We will use the AVI OVA Uploaded by Powershell |
| vCenter Server | vcsa.tkgs.tanzuathome.net | This is the nested vCenter created by Powershell |
| Content Library | AVI | This is the content library created by Powershell |
| AVI OVA Image | controller-21.1.1-9045 | This is the AVI OVA uploaded by Powershell |
| **VMware NSX Advanced Load Balancer Section** |
| AVI FQDN | nsx-alb.tkgs.tanzuathome.net | DNS Entry from Above |
| AVI Controller IP | 192.168.138.9 | DNS Entry from Above |
| Management Network Segment | Supervisor-Management-Network | |
| Management Gateway CIDR | 192.168.138.1/24 | |







### Run the Service Installer

1. Login to the new vCenter (https://vcsa.tkgs.tanzuathome.net/ui) (administrator@vsphere.local/VMware1!)
1. SSH into the Service Installer VM (ssh root@192.168.128.23) password is: TaB5!@9Y

arcas --env vsphere --file /opt/vmware/arcas/src/vsphere.json --avi_configuration \
  --avi_wcp_configuration --enable_wcp --create_supervisor_namespace \
  --create_workload_cluster

## Resources

Vault page: https://vault.vmware.com/group/vault-main-library/service-installer-for-vmware-tanzu

Arcas FAQ: https://vault.vmware.com/group/vault-main-library/document-preview/-/document_library/6KC5yhh3TpWl/view_file/72967477

## Troubleshooting

Arcas Logging is in the Arcas VM at /var/log/server
