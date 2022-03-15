# Tanzu In The Home Lab

Scripts and automation for creating home lab environments for various Tanzu products

This repository contains powershell scripts for automating vSphere infrastructure. You will need to install
VMware PowerCLI to make this work: https://developer.vmware.com/powercli

| Environment | Automation |
|---|---|
| [TKGs and NSX Advanced Load Balancer](tkgs-dvs) | Powershell script and Tanzu Service Installer |

## My Home Lab Environment

My home lab is a single physical host. Some flavors of Tanzu Kubernetes Grid (TKG) require a minimum of three hosts. For this
and other reasons, my preferred method of installing TKG is with a nested environment. This has the added benefit of being easy
to recreate - I can easily delete a nested environment and start over again if something goes horribly wrong.

Networking is another issue - as it always is. Some of the flavors of TKG require L2 isolation between networks. I manage this with
VLANs configured in my Ubiquiti EdgeRouter X. My home lab is isolated from the rest of my home network behind the EdgeRouter. I can't recommend
this little appliance enough - for around $60 you can create everything you need in a typical homelab.

In my EdgeRouter and vCenter, I have configured several utility VLANs that can be used by the various nested environments. One important
thing is to configure the vCenter port groups to accept promiscuous mode and forged transmits.

| VLAN | CIDR             | DHCP Range         | vCenter Port Group | Intended Use                  |
|------|------------------|--------------------|--------------------|-------------------------------|
| 133  | 192.168.133.0/24 | 192.168.133.10-100 | vm-network-133     | TKGm Workload and VIP Network |
| 134  | 192.168.134.0/24 | N/A                | vm-network-134     | TKGm Management Network       |
| 138  | 192.168.138.0/24 | N/A                | vm-network-138     | TKGs Management Network       |
| 139  | 192.168.139.0/24 | N/A                | vm-network-138     | TKGs Workload and VIP Network |


## Acknowledgement

The powershell scripts in this repository are based on scripts originally published by William Lam here: 
https://github.com/lamw/vsphere-with-tanzu-nsx-advanced-lb-automated-lab-deployment
