# Install TAP

## Pre-Requisites

- Kubernetes Cluster Created
- TAP Image Repository: harbor.tanzuathome.net/tap
- TAP Build registry: harbor.tanzuathome.net/tap-builds

## Bootstrap Machine

Ubuntu server VM tap-bootstrap. jeff/VMware1!

SSH to the machine, then...

```shell
sudo apt update
sudo apt upgrade
sudo apt install open-vm-tools
sudo apt install git
```

1. Install Docker, setup non-root access. Instructions here: https://docs.docker.com/engine/install/ubuntu/
2. Install homebrew from here: https://brew.sh/
3. Install Kubernetes CLI: `brew install kubernetes-cli`
4. Install Carvel tools:
   - `brew tap vmware-tanzu/carvel`
   - `brew install ytt kapp kbld kctrl imgpkg vendir`

Install Tanzu CLI following instructions here: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-tanzu-cli.html
I download the TAR on my workstation, then SFTP it to the bootstrap machine. How to SFTP:

- `sftp jeff@192.168.141.39`
- `put /Users/jefbutler/downloads/tanzu-framework-linux-amd64-v0.25.4.5.tar`
- `exit`

## Relocate Images

Make a library on Harbor called `tap`

Find current version...
```shell
imgpkg tag list -i registry.tanzu.vmware.com/tanzu-application-platform/tap-packages | grep -v sha | sort -V
```

Set environment variables...

```shell
export INSTALL_REGISTRY_USERNAME=admin
export INSTALL_REGISTRY_PASSWORD=Harbor12345
export INSTALL_REGISTRY_HOSTNAME=harbor.tanzuathome.net
export TAP_VERSION=1.5.1
export INSTALL_REPO=tap
```

```shell
docker login registry.tanzu.vmware.com
```

```shell
docker login harbor.tanzuathome.net
```

Relocate images...
```shell
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages
```

## Install TAP

```shell
export KUBECONFIG=$HOME/tap-cluster-kubeconfig-admin.yaml
```

```shell
kubectl create ns tap-install
```

```shell
tanzu secret registry add tap-registry \
  --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
  --server ${INSTALL_REGISTRY_HOSTNAME} \
  --export-to-all-namespaces --yes --namespace tap-install
```

```shell
tanzu secret registry add registry-credentials \
    --server harbor.tanzuathome.net \
    --username admin \
    --password Harbor12345 \
    --namespace tap-install \
    --export-to-all-namespaces \
    --yes
```

```shell
tanzu package repository add tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages:$TAP_VERSION \
  --namespace tap-install
```

```shell
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values.yaml -n tap-install
```

Setup cluster issuer for LetsEncrypt:
```shell
kubectl apply -f cert-manager-setup.yaml
```

Find Build Service Version...
```shell
tanzu package available list buildservice.tanzu.vmware.com --namespace tap-install
```

Relocate build service dependenciaes...
```shell
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/full-tbs-deps-package-repo:1.10.9 \
  --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tbs-full-deps
```

```shell
tanzu package repository add tbs-full-deps-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tbs-full-deps:1.10.9 \
  --namespace tap-install
```

```shell
tanzu package install full-tbs-deps -p full-tbs-deps.tanzu.vmware.com -v 1.10.9 -n tap-install
```

Get IP address for ingress and setup the DNS record...

```shell
kubectl get svc -n tanzu-system-ingress
```

## Dev Namespace Provision

```shell
kubectl create ns jgb-dev
```

```shell
kubectl label namespaces jgb-dev apps.tanzu.vmware.com/tap-ns=""
```

```shell
kubectl get secrets,serviceaccount,rolebinding,pods,workload,configmap -n jgb-dev
```

Setup RBAC for a developer... (https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/namespace-provisioner-legacy-manual-namespace-setup.html#enable-additional-users-with-kubernetes-rbac-1)

```shell
kubectl apply -f dev-role-binding.yaml
```

Add Default Maven test Pipeline...
```shell
kubectl apply -f java-maven-test-pipeline.yaml
```

Add Default Scan Policy...
```shell
kubectl apply -f scan-policy.yaml
```

Retrieve a non-admin Kubceconfig for developer use:

```shell
tanzu cluster kubeconfig get tap-cluster --export-file tap-cluster-kubeconfig-non-admin.yaml
```

## Setup Developer Workstation

1. Install the Tanzu CLI per instructions with TAP.
2. Add the pinniped-auth plugin to the Tanzu CLI: `tanzu plugin install pinniped-auth`
3. Merge the Kubeconfig file into .kube/config:
   - if no other contexts, sinply copy the contents into that file
   - else, `export KUBECONFIG=<<the file>>`, the `kubectl config view --flatten`, then copy the results into the file  
4. Set default namespace:
   - `kubectl config use-context tanzu-cli-tap-cluster@tap-cluster`
   - `kubectl config set-context --current --namespace=jgb-dev`


```shell
tanzu apps workload create java-payment-calculator \
  --git-repo https://github.com/jeffgbutler/java-payment-calculator \
  --git-branch main \
  --type web \
  --label app.kubernetes.io/part-of=java-payment-calculator \
  --label apps.tanzu.vmware.com/has-tests=true \
  --annotation autoscaling.knative.dev/minScale=1 \
  --build-env "BP_JVM_VERSION=17" \
  --namespace jgb-dev
```

```shell
tanzu apps workload create tanzu-java-web-app \
  --git-repo https://github.com/jeffgbutler/tanzu-java-web-app \
  --git-branch main \
  --type web \
  --label app.kubernetes.io/part-of=tanzu-java-web-app \
  --label apps.tanzu.vmware.com/has-tests=true \
  --annotation autoscaling.knative.dev/minScale=1 \
  --build-env "BP_JVM_VERSION=17" \
  --namespace jgb-dev
```

## Uninstall

Uninstall apps...

Delete developer namespaces...

```shell
kubectl delete ns jgb-dev
```

```shell
tanzu package installed delete full-tbs-deps -n tap-install

tanzu package installed delete tap -n tap-install
```

Uninstall package repositories...

```shell
tanzu package repository delete tanzu-tap-repository -n tap-install

tanzu package repository delete tbs-full-deps-repository -n tap-install
```

Delete namespaces...

```shell
kubectl delete ns tap-install
```
