# TKGM Install - Non Nested Environment

Install notes for TKGm install in the base vCenter on a single subnet.

## DNS Entries

| Name                         | Address         |
|------------------------------|-----------------|
| nsx-alb.tkgm.tanzuathome.net | 192.168.141.254 |

## Network Definitions

Use a flat network (single subnet) 192.168.141.0/24. This is VLAN 141, and network name
vm-network-141 on vSphere.

| IP Address(es)        | Use                                 | Where Specified       |
|-----------------------|-------------------------------------|-----------------------|
| 192.168.141.10 - 128  | DHCP Range for Nodes                | Edge Router Config    |
| 192.168.141.129 - 239 | VIP Pool for Load Balancers and API | NSX ALB Configuration |
| 192.168.141.240 - 253 | NSX ALB Service Engines             | NSX ALB Configuration |
| 192.168.141.254       | NSX ALB                             | NSX ALB OVA           |

## Install NSX ALB

1. Download the NSX ALB OVA from https://portal.avipulse.vmware.com/software/vantage
1. Upload the OVA, set the static IP address to 192.168.141.254
1. Power on the OVA and navigate to https://nsx-alb.tkgm.tanzuathome.net
1. Set password admin/VMware1!
1. Follow the instructions here: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/2.1/tkg-deploy-mc-21/mgmt-reqs-network-nsx-alb-install.html

Make sure to set the DNS server to 192.168.128.1!!!

Remember to change the system cert to the newly generated cert!

## Bootstrap Machine

Ubuntu Desktop VM tkgm-bootstrap. jeff/VMware1!

Access the VM through VMware remote console, then install ssh for future use:

   - `sudo apt install openssh-server`
   - `sudo ufw allow ssh`

Reserve DHCP address for the bootstrap machine (192.168.141.10 in my case).


SSH to the machine, then...

1. Install Docker, setup non-root access. Instructions here: https://docs.docker.com/engine/install/ubuntu/
2. Install homebrew from here: https://brew.sh/
3. Install Kubernetes CLI: `brew install kubernetes-cli`
4. Install Carvel tools:
   - `brew tap vmware-tanzu/carvel`
   - `brew install ytt kapp kbld kctrl imgpkg vendir`

Install Tanzu CLI following instructions here: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/2.1/tkg-deploy-mc-21/install-cli.html
I download the TAR on my workstation, then SFTP it to the bootstrap machine. How to SFTP:

- `sftp jeff@192.168.141.16`
- `put /Users/jefbutler/downloads/tanzu-cli-bundle-linux-amd64.tar.gz`
- `exit`

Make an RSA key for use during the TKGM install:

```shell
ssh-keygen -t rsa -b 4096 -C "jeffgbutler@gmail.com"
```

Import the base image templates.

## Create Management Cluster

Note: FireFox will fail to use the DNS server by default. Go into FireFox network settings and disable DNS over HTTPS
to fix it.

1. Login to the bootstrap maching with VMware Remote Console
1. Run `tanzu management-cluster create --ui` and configure the management cluster
1. Login to the Edge router and reserve the Management control plane DHCP address (https://192.168.128.1)

After this, we will use SSH to the bootstrap machine for all other operations.

## Trust Private CA (Optional)
If your root CA is private and not trusted by TKG, then we need to configure the infrastructure to 
add the CA to the nodes it creates.  Followed instructions here: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.4/vmware-tanzu-kubernetes-grid-14/GUID-cluster-lifecycle-secrets.html#trust-custom-ca-certificates-on-cluster-nodes-3

1. SSH into bootstrap machine (ssh jeff@192.168.141.10)
1. Add a file called `harbor-cert.yaml` in ~/.config/tanzu/tkg/providers/infrastructure-vsphere/ytt. set contents as shown in instructions
1. Create a file called `kg-custom-ca.pem` in the same directory, add the LetsEncrypt R3 PEM encoded cert

## Push an Image into Harbor for Testing

`docker pull jeffgbutler/payment-calculator`
`docker tag jeffgbutler/payment-calculator harbor.tanzuathome.net/library/payment-calculator`
`docker login harbor.tanzuathome.net`
`docker push harbor.tanzuathome.net/library/payment-calculator`

## Create Workload Cluster

Copy the management cluster yaml from ~/.config/tanzu/tkg/clusterconfigs to file `workload-cluster-1.yaml`

Change or set the `CLUSTER_NAME` value to "workload-cluster-1", leave everything else the same

Create workload cluster

`tanzu cluster create -f workload-cluster-1.yaml`

(remember to reserve the control plane IPs in DHCP)

`tanzu cluster kubeconfig get workload-cluster-1 --admin`

`kubectl config use-context workload-cluster-1-admin@workload-cluster-1`

## Try Local Harbor

`kubectl run payment-calculator --image=harbor.tanzuathome.net/library/payment-calculator`

`kubectl expose pod payment-calculator --type=LoadBalancer --name=payment-calculator --port=80 --target-port=8080`

`tanzu cluster scale workload-cluster-1 --worker-machine-count 3`

## Export Credentials

tanzu cluster kubeconfig get workload-cluster-1 --admin --export-file workload-cluster-1-credentials.yaml

kubectl get pods -A --kubeconfig=workload-cluster-1-credentials.yaml

tanzu cluster kubeconfig get tap-cluster --admin --export-file tap-cluster-credentials.yaml

kubectl get nodes --kubeconfig=tap-cluster-credentials.yaml

## Uninstall Tanzu CLI

1. `rm /usr/local/bin/tanzu`
1. `rm -r ~/.config/tanzu`
1. `rm -r ~/.cache/tanzu`
