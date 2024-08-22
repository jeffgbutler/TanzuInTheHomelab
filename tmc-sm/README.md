# Installing TMC Self Managed

Documentation is here: https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.3/tanzumc-sm-install/index-sm-install.html

DNS Records:

| Record                                  | IP Address    |
|-----------------------------------------|---------------|
| tmc.tanzuathome.net                     | 192.168.139.8 |
| alertmanager.tmc.tanzuathome.net        | 192.168.139.8 |
| auth.tmc.tanzuathome.net                | 192.168.139.8 |
| blob.tmc.tanzuathome.net                | 192.168.139.8 |
| console.s3.tmc.tanzuathome.net          | 192.168.139.8 |
| gts-rest.tmc.tanzuathome.net            | 192.168.139.8 |
| gts.tmc.tanzuathome.net                 | 192.168.139.8 |
| landing.tmc.tanzuathome.net             | 192.168.139.8 |
| pinniped-supervisor.tmc.tanzuathome.net | 192.168.139.8 |
| prometheus.tmc.tanzuathome.net          | 192.168.139.8 |
| s3.tmc.tanzuathome.net                  | 192.168.139.8 |
| tmc-local.s3.tmc.tanzuathome.net        | 192.168.139.8 |

## Prerequisites

1. Harbor should be installed
1. Create a public Harbor project harbor.tanzuathome.net/tmc

### Create the Cluster

```shell
kubectl vsphere login --server 192.168.139.6 \
  -u administrator@vsphere.local \
  --insecure-skip-tls-verify
```

```shell
kubectl apply -f 00-createcluster.yaml
```

### Setup Okta Application for OIDC

Follow steps here: https://vstellar.com/2023/08/tanzu-mission-control-self-managed-part-3-configure-idp/

1. Create groups "tmc:admin" and "tmc:member"
2. Redirect URL is https://pinniped-supervisor.tmc.tanzuathome.net/provider/pinniped/callback


### Bootstrap Machine

Ubuntu Server VM tkgm-bootstrap. jeff/VMware1!

SSH to the machine, then...

```shell
sudo apt update
sudo apt upgrade
sudo apt install open-vm-tools
sudo apt install vim
```

1. Install homebrew from here: https://brew.sh/
2. Install Kubernetes CLI: `brew install kubernetes-cli`
3. Install Carvel tools:
   - `brew tap vmware-tanzu/carvel`
   - `brew install imgpkg`
4. Install Tanzu CLI:
   - `brew update`
   - `brew install vmware-tanzu/tanzu/tanzu-cli`
5. Install the TKG Plugin Group:
   - `tanzu plugin group search --show-details`
   - `tanzu plugin group search --name vmware-tkg/default --show-details`
   - `tanzu plugin install --group vmware-tkg/default:v2.5.1`
   - `tanzu plugin group get vmware-tkg/default:v2.5.1`
   - `tanzu plugin list`

vSphere Plugin for Kubectl:
1. Download the vSphere plugin for kubectl from the namespace screen
2. Unzip
3. sftp kubectl-vsphere to the bootstrap machine
4. Move kubectl-vsphere to /usr/local/bin

```shell
kubectl vsphere login --server 192.168.139.6 --tanzu-kubernetes-cluster-namespace test-namespace \
  --tanzu-kubernetes-cluster-name tmc-sm-cluster -u administrator@vsphere.local \
  --insecure-skip-tls-verify
```
### Install Cert Manager on the Target Cluster

Used Tanzu packages here: https://docs.vmware.com/en/VMware-Tanzu-Packages/2024.4.12/tanzu-packages/index.html

```shell
imgpkg tag list -i projects.registry.vmware.com/tkg/packages/standard/repo

tanzu package repository add tanzu-standard --url "projects.registry.vmware.com/tkg/packages/standard/repo:v2.2.0_update.2" --namespace tkg-system

kubectl create ns cert-manager

tanzu package install cert-manager -p cert-manager.tanzu.vmware.com -n cert-manager -v 1.10.2+vmware.1-tkg.1
```

Setup Cluster Issuer

```shell
kubectl apply -f cert-manager-setup.yaml
```

## Install TMC

Download the tmc-sm installer package, then SFTP it to the bootstrap machine

```shell
mkdir tanzumc

tar -xf tmc_self_managed_1.3.0.tar -C ./tanzumc

tanzumc/tmc-sm push-images harbor --project harbor.tanzuathome.net/tmc --username admin --password Harbor12345

kubectl create namespace tmc-local

kubectl label ns tmc-local pod-security.kubernetes.io/enforce=privileged

tanzu package repository add tanzu-mission-control-packages --url "harbor.tanzuathome.net/tmc/package-repository:1.3.0" --namespace tmc-local

tanzu package repository list --namespace tmc-local

tanzu package available get "tmc.tanzu.vmware.com/1.3.0" --namespace tmc-local --values-schema
```

Create values.yaml

```shell
tanzu package install tanzu-mission-control -p tmc.tanzu.vmware.com --version "1.3.0" --values-file values.yaml --namespace tmc-local --debug

tanzu package install tanzu-mission-control -p tmc.tanzu.vmware.com --version "1.3.0" --values-file values-manual-certs.yaml --namespace tmc-local --debug

tanzu package installed update tanzu-mission-control -p tmc.tanzu.vmware.com -v "1.3.0" --values-file values.yaml -n tmc-local

tanzu package installed delete tanzu-mission-control -n tmc-local -y
```



```shell
kubectl run payment-calculator --restart=Never --image=jeffgbutler/payment-calculator

kubectl expose pod payment-calculator --type=LoadBalancer --port=80 --target-port=8080
```
