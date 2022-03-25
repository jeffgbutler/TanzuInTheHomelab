# Tanzu In The Home Lab

Scripts and automation for creating home lab environments for various Tanzu products

This repository contains PowerShell scripts for automating vSphere infrastructure. See this page
for helpful tips: [PowerShell Tips](PowershellNotes.md)

| Environment | Automation |
|---|---|
| [TKGm and NSX Advanced Load Balancer](tkgm-vds) | PowerShell script and Tanzu Service Installer |
| [TKGs and NSX Advanced Load Balancer](tkgs-vds) | PowerShell script and Tanzu Service Installer |

## My Home Lab Environment

My home lab is a single physical host. Some flavors of Tanzu Kubernetes Grid (TKG) require a minimum of three hosts. For this
and other reasons, my preferred method of installing TKG is with a nested environment. This has the added benefit of being easy
to recreate - I can easily delete a nested environment and start over again if something goes horribly wrong.

Networking is another issue - as it always is. Some of the flavors of TKG require L2 isolation between networks. I manage this with
VLANs configured in an Ubiquiti EdgeRouter X. My home lab is isolated from the rest of my home network behind the EdgeRouter. There
are other approaches out there that don't require VLANs (usually involving the creation of router VMs). In my case it seems simpler
to do VLANs - but you need a router then can support them. For around $60, the EdgeRouterX is a simple solution.

Configuring VLANs can be confusing. Here's a good video showing a simple setup for EdgeOS: https://www.youtube.com/watch?v=3j6RiovCFz0

In the EdgeRouter and vCenter, I have configured several utility VLANs that can be used by the various nested environments. One important
thing is to configure the vCenter port groups to accept promiscuous mode and forged transmits.

| VLAN | CIDR             | DHCP Range         | vCenter Port Group | Intended Use                    |
|------|------------------|--------------------|--------------------|---------------------------------|
| 132  | 192.168.132.1/24 | N/A                | vm-network-132     | TKGm Workload Data Network      |
| 133  | 192.168.133.1/24 | 192.168.133.10-128 | vm-network-133     | TKGm Management Network (DHCP)  |
| 134  | 192.168.134.1/24 | 192.168.134.10-128 | vm-network-134     | TKGm Workload Network (DHCP)    |
| 135  | 192.168.135.1/24 | N/A                | vm-network-135     | TKGm Management Data Network    |
| 136  | 192.168.136.1/24 | N/A                | vm-network-136     | TKGm NSX ALB Management Network |
| 137  | 192.168.137.1/24 | N/A                | vm-network-137     | TKGm VIP Network Range          |
| 138  | 192.168.138.1/24 | N/A                | vm-network-138     | TKGs Management Network         |
| 139  | 192.168.139.1/24 | N/A                | vm-network-138     | TKGs Workload and VIP Network   |


## Acknowledgement

The PowerShell scripts in this repository are based on scripts originally published by William Lam here: 
https://github.com/lamw/vsphere-with-tanzu-nsx-advanced-lb-automated-lab-deployment
