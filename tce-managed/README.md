# Tanzu Community Edition (TCE) on vSphere

Instructions for installing Tanzu Community Edition (TCE) on vSphere.

## Download the OVA

Create a VM folder named "tanzu-community-edition".

Download a Kubernetes OVA from VMware Customer Connect: https://customerconnect.vmware.com/downloads/get-download?downloadGroup=TCE-0110 (I downloaded Photon v3 Kubernetes v1.22.5 OVA)

Import the OVA into vCenter in the "tanzu-community-edition" folder. I specified the following settings:

- Storage: VMStorage
- Network: vm-network-140 (this is my network with DHCP for TCE)

Once the OVA is uploaded, convert it to a template (Right click, Template -> Convert to Template)

## Create and Configure a Bootstrap VM

Create a VM for working with TCE. The VM I created has the following characteristics:

- Ubuntu Desktop 20.04 (LTS)
- 8 vCPU
- 32 GB RAM
- 256 GB Storage

I did a minimal install initially. We will add a few items...

### Install OpenSSH Server

SSH can be usefull in many cases, so let's install it:

```shell
sudo apt-get update

sudo apt-get install openssh-server

sudo ufw allow ssh
```

### Install Docker

Install Docker based on the instructions at https://docs.docker.com/engine/install/ubuntu/

Make sure to setup the docker group so you can run docker without sudo.

### Install Homebrew

Install homebrew with instructions from here: https://brew.sh/

It is important to follow the post install steps for downloading the brew dependencies and installing gcc!

### Install Kubectl

```shell
brew install kubectl
```

### Install TCE

```shell
brew install vmware-tanzu/tanzu/tanzu-community-edition

/home/linuxbrew/.linuxbrew/Cellar/tanzu-community-edition/v0.11.0/libexec/configure-tce.sh
```

### Create an SSH Key

```shell
ssh-keygen -t rsa -b 4096 -C "jeffgbutler@gmail.com"
```

## Create a Management Cluster

(This will open a browser, so it cannot be done from SSH. Login to the VM and open a terminal instead.)

```shell
tanzu management-cluster create --ui
```

Select the provider for vSphere and follow the wizard. This was very straight forward. Mainly pay attention
to networking:

- Network: vm-network-140
- Control Plane Endpoint: 192.168.140.240

## Create a Workload Cluster

Copy the workload cluster configuration (note that the filename will be different for different installs, but it is
usually the only file in the directory after an initil install):

```shell
mkdir tce-config

cp ~/.config/tanzu/tkg/clusterconfigs/z8c6uhzh1p.yaml .

mv z8c6uhzh1p.yaml workload-cluster.yaml
```

Edit the file and change the following settings at a minimum:

- CLUSTER_NAME: workload-cluster
- VSPHERE_CONTROL_PLANE_ENDPOINT: 192.168.140.241
- WORKER_MACHINE_COUNT: "3"

Save the file, then create the cluster:

```shell
tanzu cluster create --file workload-cluster.yaml
```

Once the cluster is created, gain access to it through Kubeconfig:

This will add the config to your context for easy use:

```shell
tanzu cluster kubeconfig get workload-cluster --admin
```

This will export the config so you can use it on different machines:

```shell
tanzu cluster kubeconfig get workload-cluster --admin --export-file workload-cluster-kubeconfig.yaml
```

## Install MetalLB for LoadBalancing

For this install, I did not install NSX Advanced Load Balancer. Rather, I will use MetalLB for providing support
for LoadBalancer services in a workload cluster. This post by William Lam is helpful: https://williamlam.com/2021/10/quick-tip-install-metallb-as-service-load-balancer-with-tanzu-community-edition-tce.html

```shell
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/metallb.yaml
```

Create a configuration file for MetalLB:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.140.220-192.168.140.239
```

Apply the config map:

```shell
kubectl apply -f metallb-config.yaml
```

Test it:

```shell
kubectl run kuard --restart=Never --image=gcr.io/kuar-demo/kuard-amd64:blue

kubectl expose pod kuard --type=LoadBalancer --port=80 --target-port=8080
```
