# Install TKGm with Tanzu Service Installer

Instructions for installing Tanzu Kubernetes Grid (TKGm) with NSX Advanced Load Balancer (AVI) in a nested homelab environment.

This nested environment is created in two steps:

1. Run a PowerShell script to create a nested vCenter. The nested vCenter has these attributes:
   - 3 nested ESXi Hosts
   - 6 Portgroups mapped to VLANs in the outer vCenter
   - A Shared VSAN data store
1. Use the Tanzu Service Installer (a.k.a. Arcas) to enable and configure TKGm in the nested vCenter

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
1. NSX Advanced LoadBalancer (aka AVI Vantage) - Currently Arcas supports version 20.1.7
   - Download NSX ALB from https://customerconnect.vmware.com/downloads/details?downloadGroup=NSX-ALB-10-NDC&productId=1092
   - Update the `$NSXAdvLBOVA` script variable with the location of the downloaded OVA
1. Kubernetes VM template from https://marketplace.cloud.vmware.com/services/details/tanzu-kubernetes-grid-1-1-1211?slug=true
   - These instructions assume Photon and Kubernetes version 1.22.5

## Procedure Part 1: Nested Infrastructure

The PowerShell script `nestedEsxiForTKGm.ps1` in this folder will create a nested vSphere environment for installing TKGm.

There are a large set of variables at the beginning of this script that define the nested environment. The most
important of these are the IP addresses, domain names, and network names from the outer vCenter. The values in the script
are based on my home lab network. I am using four VLANs - two of which have DHCP enabled which is a requirement for TKGm.
In your environment you may need to change these values. You will also see multiple references to a domain `tanzuathome.net`
that I own. You should change these values to match a domain that you control, and where you can manage DNS entries.

 Before running the script, you should create DNS entries to match entries in the script. In my environment, I use
 the following DNS records:

| Name                              | Address       |
|-----------------------------------|---------------|
| vcsa.tkgm.tanzuathome.net         | 192.168.136.3 |
| tkgm-esxi-1.tkgm.tanzuathome.net  | 192.168.136.4 |
| tkgm-esxi-2.tkgm.tanzuathome.net  | 192.168.136.5 |
| tkgm-esxi-3.tkgm.tanzuathome.net  | 192.168.136.6 |
| nsx-alb.tkgm.tanzuathome.net      | 192.168.136.9 |

After the script variables have been set and the DNS entries creatred, run the script `nestedEsxiForTKGm.ps1`.
This will create a new vCenter with three nested ESXi hosts. The script will run for approximately 40 minutes.

**Important:** the vCenter install will fail if you are on the VMware VPN!

## Procedure Part 2: Enable Kubernetes with Tanzu Service Installer

### Pre Reqs for TKGm

Download the VM template for Kubernetes. Install it in the vCenter and convert it to a template.

Download the v1.22.5 photon VM from here: https://marketplace.cloud.vmware.com/services/details/tanzu-kubernetes-grid-1-1-1211?slug=true

### About Tanzu Service Installer

Tanzu Service Installer (a.k.a "arcas") is a VMware internal tool that automates many of the aspects of installing Tanzu Kubernetes Grid
Multi-Cloud in vSphere (a.k.a TKGm).

Arcas runs in a purpose built VM that is installed in vSphere. It is installed via an OVA downloaded from the VMware marketplace.

Arcas automates many of the tedious tasks with enabling Tanzu Kubernetes Grid - most notably the configuration of NSX
Advanced Load Balancer. Arcas is very opinionated about how your Kubernetes environment and your networks are
designed. As of version 1.1, arcas deploys Tanzu Kubernetes Grid according to the published reference architecture -
which means 6 subnets and a sharded services cluster. You must still think deeply about network and cluster design. I will discuss how
the networks are designed in my home lab.

### Network Design

The reference architecture for TKGm uses six networks - two of which need DHCP enabled.

When designing a Kubernetes environment it is also important to be mindful of the networks that exist inside
a Kubernetes cluster - those networks cannot overlap each other, and should not overlap with other
networks in use. The table below shows the network design for TKGm in my home lab:

| Network                         | vSphere Port Group | IP or Range        |
|---------------------------------|--------------------|--------------------|
| nsx-alb.tkgm.tanzuathome.net    | vlan-136           | 192.168.136.9      |
| NSX ALB Management Network      | vlan-136           | 192.168.136.20-69  |
| VIP Network Range               | vlan-137           | 192.168.137.20-69  |
| Management Data Network         | vlan-135           | 192.168.135.20-69  |
| Workload Data Network           | vlan-132           | 192.168.132.20-69  |
| Management Network (DHCP)       | vlan-133           | 192.168.133.10-128 |
| Workload Network (DHCP)         | vlan-134           | 192.168.134.10-128 |
| K8S POD CIDR (All Clusters)     | N/A                | 100.96.0.0/11      |
| K8S Service CIDR (All Clusters) | N/A                | 100.64.0.0/13      |

### Tanzu Service Installer as a Data Collector

When you run the service installer, you will need to supply many configuration variables. These are the same variables you will
need when installing TKGm in a customer environment - so you can think if the service installer as a kind of "data collector" for
configuration variables you will need.

The file `vsphere-dvs-tkgm.json` in this folder contains the output from running arcas with the configuration variables
that are appropriate for my home lab.

### Run the Service Installer

1. Download and deploy the OVA for service installer in your vCenter. You can use either the outer vCenter, or the
   nested vCenter. For TKGm it makes sense to use the inner vCenter as the Arcas VM will be very useful after the install -
   it contains many utilities that can be used to manage TKGm. If you use the inner vCenter, use the management network
   (vlan-136 in my homelab) and use an IP address outside the range specified for NSX ALB
1. Access the service installer user interface via a browser. It is available on port 8888 of the VM. For me, this is
   http://192.168.128.28:8888
1. Arcas can create configurations for several different types of vSphere installs. These instructions are based on
   Deploying TKGm with "Tanzu Kubernetes Grid Multi-Cloud on VMware vSphere with DVS"
1. Start the wizard for "Tanzu Kubernetes Grid Multi-Cloud on VMware vSphere with DVS" and enter the appropriate values for your installation
   (see `vsphere-dvs-tkgm.json` in this folder for an example)
1. Once finished, save the configuration to the arcas VM. It will be saved at `/opt/vmware/arcas/src/vsphere-dvs-tkgm.json`
1. SSH into the Service Installer VM (ssh root@192.168.128.28)
1. Run the following command:

   ```shell
   arcas --env vsphere --file /opt/vmware/arcas/src/vsphere-dvs-tkgm.json \
      --avi_configuration --tkg_mgmt_configuration \
      --shared_service_configuration --workload_preconfig --workload_deploy --deploy_extensions
   ```

1. Using the values I supplied, this will do the following:

   - Install and configure NSX Advanced Load Balancer
   - Create a Management Cluster
   - Create a Shared Services Cluster with Harbor
   - Create a Workload cluster

## After Running the Service Installer

### Access Harbor

1. SSH into the service installer VM
1. Find the context for the shared services cluster

   ```shell
   kubectl config get-contexts
   ```

   In my case the context was `shared-service-cluster-admin@shared-service-cluster`

1. Access the shared services cluster

   ```shell
   kubectl config use-context shared-service-cluster-admin@shared-service-cluster
   ```

1. Find the IP address of the Envoy service

   ```shell
   kubectl get svc envoy -n tanzu-system-ingress
   ```

1. Show the domain name for the harbor install

   ```shell
   kubectl get httpproxy -A
   ```

1. Add a DNS "A" record for the Harbor host and the Envoy IP address. For my homelab it was `harbor.tkgm.tanzuathome.net`
   and `192.168.135.20`

### Try a Deployment on the Workload Cluster

1. SSH into the service installer VM
1. Find the context for the workload cluster

   ```shell
   kubectl config get-contexts
   ```

   In my case the context was `workload-cluster-admin@workload-cluster`

1. Access the workload cluster

   ```shell
   kubectl config use-context workload-cluster-admin@workload-cluster
   ```

1. Deploy and expose Kuard

   ```shell
   kubectl run kuard --restart=Never --image=gcr.io/kuar-demo/kuard-amd64:blue

   kubectl expose pod kuard --type=LoadBalancer --port=80 --target-port=8080
   ```

   After this, you should be able to hit kuard at the IP exposed by the load balancer. You can retrive the IP address with this
   command: `kubectl get svc kuard`. Hit Kuard with the external-ip, for me it was http://192.168.132.20

   Note that the first time you expose a service in the workload cluster it will take a long time to come up because AVI will create
   new service engine instances.

## Resources

Vault page: https://vault.vmware.com/group/vault-main-library/service-installer-for-vmware-tanzu

Arcas FAQ: https://vault.vmware.com/group/vault-main-library/document-preview/-/document_library/6KC5yhh3TpWl/view_file/72967477

## Troubleshooting

Arcas Logging is in the Arcas VM at /var/log/server

Follow progress in the Arcas VM: `journalctl -u arcas.service --follow`
