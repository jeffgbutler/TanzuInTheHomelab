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
   - Download the latest nested ESXi appliance from William Lam: https://williamlam.com/nested-virtualization/nested-esxi-virtual-appliance
   - Update the `$NestedESXiApplianceOVA` script variable with the location of the downloaded OVA
1. vCenter
   - Download the vCenter server appliance ISO from my.vmware.com or buildweb.vmware.com (internal)
   - Mount the ISO and copy all files/directories into a directory on your disk
   - Update the `$VCSAInstallerPath` script variable with the location of the directory
   - If you are on a Mac, disable gatekeeper with a command similar to the following:
     `sudo xattr -r -d com.apple.quarantine VMware-VCSA-all-7.0.3-19234570`
1. NSX Advanced LoadBalancer (aka AVI Vantage)
   - Download NSX ALB from https://customerconnect.vmware.com/downloads/details?downloadGroup=NSX-ALB-10-NDC&productId=1092
   - Update the `$NSXAdvLBOVA` script variable with the location of the downloaded OVA

## Procedure Part 1: Nested Infrastructure

The Powershell script `nestedEsxiForTKGs.ps1` in this folder will create a nested vSphere environment for installing TKGs.

There are a large set of variables at the beginning of this script that define the nested environment. The most
important of these are the IP addresses, domain names, and network names from the outer vCenter. The values in the script
are based on my home lab network. I am using two VLANs - `vm-network-138` and `vm-network-139` - with CIDRs `192.168.138.0/24`
 and `192.168.139.0/24` - respectively. In your environment you may need to change these values. You will also see multiple
 references to a domain `tanzuathome.net` that I own. You should change these values to match a domain that you control, and where
 you can manage DNS entries.

 Before running the script, you should create DNS entries to match entries in the script. In my environment, I use
 the following DNS records:

| Name                              | Address         |
|-----------------------------------|-----------------|
| vcsa.tkgs.tanzuathome.net         | 192.168.138.3   |
| tkgs-esxi-1.tkgs.tanzuathome.net  | 192.168.138.4   |
| tkgs-esxi-2.tkgs.tanzuathome.net  | 192.168.138.5   |
| tkgs-esxi-3.tkgs.tanzuathome.net  | 192.168.138.6   |
| nsx-alb.tkgs.tanzuathome.net      | 192.168.138.9   |

After the script variables have been set and the DNS entries created, run the script `nestedEsxiForTKGs.ps1`.
This will create a new vCenter with three nested ESXi hosts. The script will run for approximately 45 minutes.

**Important:** the vCenter install will fail if you are on the VMware VPN!

## Procedure Part 2: Enable Kubernetes with Tanzu Service Installer

### About Tanzu Service Installer

Tanzu Service Installer (a.k.a "arcas") is a VMware internal tool that automates many of the aspects of enabling workload management
in vSphere (a.k.a vSphere with Tanzu", a.k.a. Tanzu Kubernetes Grid Service - or TKGS).

Arcas runs in a purpose built VM that is installed in vSphere. It is installed via an OVA downloaded from the VMware marketplace.

Arcas automates many of the tedious tasks with enabling vSphere with Tanzu - most notably the configuration of NSX
Advanced Load Balancer. But arcas is not very opinionated about how your Kubernetes environment and your networks are
designed. This means that you must still think deeply about network and cluster design. I will discuss how the networks
are designed in my home lab.

For a TKGs installation, arcas provides two options:

1. Basic configuration and enablement of WCP (the Tanzu service in vSphere)
2. Create a workload namespace and workload cluster

We will show examples of using both.

### Network Design

TKGs uses three types of networks - management, workload, and VIP networks. This installation is based
on the two subnet model for TKGs - where the workload and VIP networks share the same subnet.

When designing a Kubernetes environment it is also important to be mindful for the networks that exist inside
a Kubernetes cluster - those networks cannot overlap each other, and should not overlap with other
networks in use. The table below shows the network design for TKGs in my home lab:

| Network      | vSphere Port Group            | Item                         | IP or Range         |
|--------------|-------------------------------|------------------------------|---------------------|
| Management   | Supervisor-Management-Network | vcsa.tkgs.tanzuathome.net    | 192.168.138.3       |
| Management   | Supervisor-Management-Network | esxi-1.tkgs.tanzuathome.net  | 192.168.138.4       |
| Management   | Supervisor-Management-Network | esxi-2.tkgs.tanzuathome.net  | 192.168.138.5       |
| Management   | Supervisor-Management-Network | esxi-3.tkgs.tanzuathome.net  | 192.168.138.6       |
| Management   | Supervisor-Management-Network | nsx-alb.tkgs.tanzuathome.net | 192.168.138.9       |
| Management   | Supervisor-Management-Network | sivt.tkgs.tanzuathome.net    | 192.168.138.10      |
| Management   | Supervisor-Management-Network | NSX Service Engines          | 192.168.138.180-187 |
| Management   | Supervisor-Management-Network | Start of 5 Address Range     | 192.168.138.190     |
| VIP          | Workload-VIP-Network          | VIP Network Range            | 192.168.139.2-126   |
| Workload     | Workload-VIP-Network          | Workload Network Range       | 192.168.139.128-254 |
| K8S Internal | N/A                           | Supervisor Service CIDR      | 10.96.0.0/22        |
| K8S Internal | N/A                           | POD CIDR                     | 10.112.0.0/12       |
| K8S Internal | N/A                           | Service CIDR                 | 10.128.0.0/16       |


### Tanzu Service Installer as a Data Collector

When you run the service installer, you will need to supply many configuration variables. These are the same variables you will
need when installing TKGs in a customer environment - so you can think if the service installer as a kind of "data collector" for
configuration variables you will need.

The file `vsphere-dvs-tkgs-wcp.json` in this folder contains the output from running arcas with the configuration variables
that are appropriate for my home lab.

### Install and Start the Service Installer

1. Download the OVA for service installer from the VMware marketplace (https://marketplace.cloud.vmware.com/)
1. Deploy the OVA in your vCenter. You can use either the outer vCenter, or the nested vCenter. I use the nested vCenter.
   Configuration values for the OVA:
   - Storage: vsanDatastore
   - Network: Supervisor-Management-Network
   - NTP Server: `pool.ntp.org`
   - Root password: `VMware1!`
   - Default Gateway: 192.168.138.1
   - Domain name: sivt.tkgs.tanzuathome.net
   - Domain search path: tkgs.tanzuathome.net
   - DNS: 192.168.128.1
   - Appliance IP address: 192.168.138.10
   - Netmask: 255.255.255.0
   - Leave all the network fields blank if you picked a network with DHCP enabled, else enter appropriate values for your network

1. Power on the VM
1. Access the service installer user interface via a browser. It is available on port 8888 of the VM. For me, this is
   http://192.168.138.10:8888

### Configuration Step 1: AVI and WCP

1. SIVT can create configurations for several different types of vSphere installs. These instructions are based on
   Deploying "Tanzu on VMware vSphere with DVS"
1. Start the wizard for "Tanzu on VMware vSphere with DVS"
1. Select Deployment type "Enable Workload Control Plane", then select "Configure and Generate JSON"
1. Enter the appropriate values for your installation (see `vsphere-dvs-tkgs-wcp.json` in this folder for
   an example)
1. Once finished, save the configuration to the arcas VM. It will be saved at `/opt/vmware/arcas/src/vsphere-dvs-tkgs-wcp.json`
1. SSH into the Service Installer VM (ssh root@192.168.138.10).
1. Run the following command:

   ```shell
   arcas --env vsphere --file /opt/vmware/arcas/src/vsphere-dvs-tkgs-wcp.json --avi_configuration --avi_wcp_configuration --enable_wcp --verbose
   ```

1. Using the values I supplied, this will do the following:

   - Install and configure NSX Advanced Load Balancer
   - Enable Workload Managment (Kubernetes)

### Configuration Step 2: Workload Namespace and Cluster

Once WCP is enabled you can create a namespace and workload cluster through the normal methods with TKGs or you can use
arcas to automate the process. We'll use arcas.

1. Start the wizard for "Tanzu on VMware vSphere with DVS"
1. Select Deployment type "Namespace and Workload Cluster", then select "Configure and Generate JSON"
1. Enter the appropriate values for your installation (see `vsphere-dvs-tkgs-namespace.json` in this folder for
   an example)
1. Once finished, save the configuration to the arcas VM. It will be saved
   at `/opt/vmware/arcas/src/vsphere-dvs-tkgs-namespace.json`
1. SSH into the Service Installer VM (ssh root@192.168.138.10).
1. Run the following command:

   ```shell
   arcas --env vsphere --file /opt/vmware/arcas/src/vsphere-dvs-tkgs-namespace.json \
      --create_supervisor_namespace --create_workload_cluster --deploy_extensions
   ```

1. Using the values I supplied, this will do the following:

   - Create a namespace called "test-namespace"
   - Create a workload cluster called "dev-cluster"

### Test the Workload Cluster

Once the workload cluster is up and running, you can find the server address by navigating to the "test-namespace"
in workload management, then copy the link to the CLI tools. For me it was "https://192.168.139.3".

```
kubectl vsphere login --server 192.168.139.3 --tanzu-kubernetes-cluster-namespace test-namespace \
  --tanzu-kubernetes-cluster-name dev-cluster -u administrator@vsphere.local \
  --insecure-skip-tls-verify

kubectl run kuard --restart=Never --image=gcr.io/kuar-demo/kuard-amd64:blue

kubectl expose pod kuard --type=LoadBalancer --port=80 --target-port=8080
```

After this, you should be able to hit kuard at the IP exposed by the load balancer. You can retrive the IP address with this
command: `kubectl get svc kuard`. Hit Kuard with the external-ip, for me it was http://192.168.139.7

## Resources

Reference Architectures: https://github.com/vmware-tanzu-labs/tanzu-validated-solutions

Vault page: https://vault.vmware.com/group/vault-main-library/service-installer-for-vmware-tanzu

Arcas FAQ: https://vault.vmware.com/group/vault-main-library/document-preview/-/document_library/6KC5yhh3TpWl/view_file/72967477

## Troubleshooting

Arcas Logging is in the Arcas VM at /var/log/server

Follow progress in the Arcas VM: `journalctl -u arcas.service --follow`
