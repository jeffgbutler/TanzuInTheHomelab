# Install TKGs with Tanzu Service Installer

Instructions for installing vSphere with Tanzu (TKGs) with NSX Advanced Load Balancer (AVI) in a nested homelab environment.

This nested environment is created in two steps:

1. Run a Powershell script to create a nested vCenter. The nested vCenter has these attributes:
   - 3 nested ESXi Hosts
   - 2 Portgroups mapped to VLANs in the outer vCenter
   - A Shared VSAN data store
   - A Content library containing the AVI controller OVA
1. Enable Workload Management Manually

## Prerequisites

### Downloads

1. ESXi
   - Download the latest nested ESXi appliance from Broadcom Flings: https://community.broadcom.com/flings/home
   - Unzip the file, then package an ova using ovftool. For example:
     `ovftool ~/NestedESXI/Nested_ESXi8.0u3_Appliance_Template_v1/Nested_ESXi8.0u3_Appliance_Template_v1.ovf ~/NestedESXI/Nested_ESXi8.0u3_Appliance_Template_v1.ova`
   - Update the `$NestedESXiApplianceOVA` script variable with the location of the OVA
1. vCenter
   - Download the vCenter server appliance ISO from https://support.broadcom.com/group/ecx/all-products or buildweb.vmware.com (internal)
   - Mount the ISO and copy all files/directories into a directory on your disk
   - Update the `$VCSAInstallerPath` script variable with the location of the directory
   - If you are on a Mac, disable gatekeeper with a command similar to the following:
     `sudo xattr -r -d com.apple.quarantine VMware-VCSA-all-7.0.3-21958406`
1. NSX Advanced LoadBalancer (aka AVI Vantage)
   - Download NSX ALB from https://portal.avipulse.vmware.com/software/vantage
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

## Procedure Part 2: Install and Configure NSX Advanced Load Balancer (AVI)

Install and configure AVI following the instructions here: https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-with-tanzu-installation-configuration/GUID-CBA041AB-DC1D-4EEC-8047-184F2CF2FE0F.html#GUID-CBA041AB-DC1D-4EEC-8047-184F2CF2FE0F

There are notes for my environment on the [NSX ALB Notes](NsxAlb-Notes.md) page.

## Procedure Part 3: Enable Kubernetes with Tanzu Service Installer

### Network Design

TKGs uses three types of networks - management, workload, and VIP networks. This installation is based
on the two subnet model for TKGs - where the workload and VIP networks share the same subnet.

When designing a Kubernetes environment it is also important to be mindful for the networks that exist inside
a Kubernetes cluster - those networks cannot overlap each other, and should not overlap with other
networks in use. The table below shows the network design for TKGs in my home lab:

2 Network Configuration:

| Network      | vSphere Port Group            | Item                              | IP or Range         |
|--------------|-------------------------------|-----------------------------------|---------------------|
| Management   | Supervisor-Management-Network | vcsa.tkgs.tanzuathome.net         | 192.168.138.3       |
| Management   | Supervisor-Management-Network | tkgs-esxi-1.tkgs.tanzuathome.net  | 192.168.138.4       |
| Management   | Supervisor-Management-Network | tkgs-esxi-2.tkgs.tanzuathome.net  | 192.168.138.5       |
| Management   | Supervisor-Management-Network | tkgs-esxi-3.tkgs.tanzuathome.net  | 192.168.138.6       |
| Management   | Supervisor-Management-Network | nsx-alb.tkgs.tanzuathome.net      | 192.168.138.9       |
| Management   | Supervisor-Management-Network | NSX Service Engines               | 192.168.138.180-187 |
| Management   | Supervisor-Management-Network | Start of 5 Address Range          | 192.168.138.190     |
| VIP (Data)   | Workload-VIP-Network          | VIP Network Range                 | 192.168.139.2-126   |
| Workload     | Workload-VIP-Network          | Workload Network Range            | 192.168.139.128-254 |
| K8S Internal | N/A                           | Supervisor Service CIDR           | 10.96.0.0/23        |
| K8S Internal | N/A                           | POD CIDR                          | 10.128.0.0/16       |
| K8S Internal | N/A                           | Service CIDR                      | 10.129.0.0/16       |

3 Network Configuration:

| Network      | vSphere Port Group | Item                              | IP or Range         |
|--------------|--------------------|-----------------------------------|---------------------|
| Management   | mgmt-vlan138       | vcsa.tkgs.tanzuathome.net         | 192.168.138.3       |
| Management   | mgmt-vlan138       | tkgs-esxi-1.tkgs.tanzuathome.net  | 192.168.138.4       |
| Management   | mgmt-vlan138       | tkgs-esxi-2.tkgs.tanzuathome.net  | 192.168.138.5       |
| Management   | mgmt-vlan138       | tkgs-esxi-3.tkgs.tanzuathome.net  | 192.168.138.6       |
| Management   | mgmt-vlan138       | nsx-alb.tkgs.tanzuathome.net      | 192.168.138.9       |
| Management   | mgmt-vlan138       | NSX Service Engines               | 192.168.138.180-187 |
| Management   | mgmt-vlan138       | Start of 5 Address Range          | 192.168.138.190     |
| VIP (Data)   | data-vlan139       | VIP Network Range                 | 192.168.139.2-254   |
| Workload     | tkgs-vlan137       | Workload Network Range            | 192.168.137.2-254   |
| K8S Internal | N/A                | Supervisor Service CIDR           | 10.96.0.0/23        |
| K8S Internal | N/A                | POD CIDR                          | 10.128.0.0/16       |
| K8S Internal | N/A                | Service CIDR                      | 10.129.0.0/16       |

### Enable TKGs

In vCenter, navigate to "Workload Management" and follow the wizard to enable TKGs. Networking values are in the table above.
You will need access to the certificate you created in AVI for this step.
You can also import the configuration from the [wcp-config.json](wcp-config.json) file as a starting point.

This step takes close to an hour to complete in my lab.

### Create a Namespace

Once the service is running, create a namespace `test-namespace` for further experimentation. At a minimum, add storage and
several VM classes to the namespace.

## Procedure Part 4: Create a Workload Cluster and Test Deployment

### Logon to the Supervisor Cluster

```shell
kubectl vsphere login --server 192.168.139.6 \
  -u administrator@vsphere.local \
  --insecure-skip-tls-verify
```

List available storage classes for the namespace:

```shell
kubectl get StorageClasses -n test-namespace
```

List available machine classes for the namespace:

```shell
kubectl get VirtualMachineClasses -n test-namespace
```

List available TKRs:

```shell
kubectl get TanzuKubernetesReleases
```

Adjust the values in [00-createcluster.yaml](00-createcluster.yaml) if desired, then

```shell
kubectl apply -f 00-createcluster.yaml
```

### Test the Workload Cluster

Once the workload cluster is up and running, you can find the server address by navigating to the "test-namespace"
in workload management, then copy the link to the CLI tools. For me it was "https://192.168.139.6".

```shell
kubectl vsphere login --server 192.168.139.6 --tanzu-kubernetes-cluster-namespace test-namespace \
  --tanzu-kubernetes-cluster-name dev-cluster -u administrator@vsphere.local \
  --insecure-skip-tls-verify
```

For vSphere 8, and TKR 1.25 or later, we need to open up the pod security admission controller.
Details here: https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-with-tanzu-tkg/GUID-B57DA879-89FD-4C34-8ADB-B21CB3AE67F6.html

```shell
kubectl label --overwrite ns default pod-security.kubernetes.io/enforce=privileged
```

Deploy a test pod and service...

```shell
kubectl run kuard --restart=Never --image=gcr.io/kuar-demo/kuard-amd64:blue

kubectl expose pod kuard --type=LoadBalancer --port=80 --target-port=8080
```

After this, you should be able to hit kuard at the IP exposed by the load balancer. You can retrive the IP address with this
command: `kubectl get svc kuard`. Hit Kuard with the external-ip, for me it was http://192.168.139.8

## Resources

Reference Architectures: https://github.com/vmware-tanzu-labs/tanzu-validated-solutions

## Troubleshooting

### Check NTP Configuration

All hosts should have NTP configured. This is a simple PowerShell command set you can use to check it:

```powershell
Connect-VIServer vcsa.tkgs.tanzuathome.net -User administrator@vsphere.local -Password VMware1!

Get-VMHost | `
Sort-Object Name | `
Select-Object Name, @{N="Cluster";E={$_ | Get-Cluster}}, @{N="Datacenter";E={$_ | Get-Datacenter}}, @{N="NTPServiceRunning";E={($_ | Get-VmHostService | Where-Object {$_.key-eq "ntpd"}).Running}}, @{N="StartupPolicy";E={($_ | Get-VmHostService | Where-Object {$_.key-eq "ntpd"}).Policy}}, @{N="NTPServers";E={$_ | Get-VMHostNtpServer}}, @{N="Date&Time";E={(get-view $_.ExtensionData.configManager.DateTimeSystem).QueryDateTime()}} | format-table -autosize

Disconnect-VIServer
```

### Logs

Sometimes it is helpful to SSH into the supervisor nodes and inspect the logs. Here's how:

1. SSH to vCenter as root, then run this command `/usr/lib/vmware-wcp/decryptK8Pwd.py` to get the SSH password for the supervisor nodes
2. SSH to any or all supervisor nodes as root using the password obtained above. Interesting logs are in `/var/log/vmware-imc/`
   particularly `/var/log/vmware-imc/configure-wcp.stderr`
