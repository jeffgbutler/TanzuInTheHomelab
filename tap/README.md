# Install TAP

## Pre-Requisites

- Kubernetes Cluster Created
- TAP Image Repository: harbor.tanzuathome.net/tap
- TAP Build registry: harbor.tanzuathome.net/tap-builds

### TKGM Settings

```shell
CLUSTER_NAME: tap-cluster
CLUSTER_PLAN: dev
VSPHERE_WORKER_DISK_GIB: "200"
VSPHERE_WORKER_MEM_MIB: "12288"
VSPHERE_WORKER_NUM_CPUS: "4"
WORKER_MACHINE_COUNT: "5"
```

### TKGM Export

```shell
tanzu cluster kubeconfig get tap-cluster --admin --export-file tap-cluster-admin.kubeconfig

tanzu cluster kubeconfig get tap-cluster --export-file tap-cluster-dev.kubeconfig
```

## Bootstrap Machine

Ubuntu server VM tap-bootstrap. jeff/VMware1!

SSH to the machine, then...

```shell
sudo apt update
sudo apt upgrade
sudo apt install open-vm-tools
sudo apt install git
sudo apt install vim
```

1. Install Docker, setup non-root access. Instructions here: https://docs.docker.com/engine/install/ubuntu/
2. Install homebrew from here: https://brew.sh/
3. Install Kubernetes CLI: `brew install kubernetes-cli`
4. Install Carvel tools:
   - `brew tap vmware-tanzu/carvel`
   - `brew install ytt kapp kbld kctrl imgpkg vendir`
5. Install Kpack CLI:
   - `brew tap vmware-tanzu/kpack-cli`
   - `brew install kp`

Install Krew and a few useful plugins:

1. Install Krew: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
2. `kubectl krew install tree`
3. `kubectl krew install secretdata`
4. `kubectl krew install get-all`

Add a Kubeconfig for the tap-cluster:

```shell
export KUBECONFIG=tap-cluster-admin.kubeconfig
```

Install Tanzu CLI following instructions here: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.10/tap/install-tanzu-cli.html

Then follow basic instructions from here: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.9/tap/install-online-profile.html

## Relocate Images

Make a project on Harbor called `tap`

Login to the following registries:
- `docker login harbor.tanzuathome.net`
- `docker login registry.tanzu.vmware.com`

Find current version...
```shell
imgpkg tag list -i registry.tanzu.vmware.com/tanzu-application-platform/tap-packages | grep -v sha | sort -V
```

If you want to exclude pre-release versions, use this command:

```shell
imgpkg tag list -i registry.tanzu.vmware.com/tanzu-application-platform/tap-packages | grep -v -E 'build|rc|sha' | sort -V
```

Set environment variables...

```shell
export INSTALL_REGISTRY_USERNAME=admin
export INSTALL_REGISTRY_PASSWORD=Harbor12345
export INSTALL_REGISTRY_HOSTNAME=harbor.tanzuathome.net
export TAP_VERSION=1.9.0
export INSTALL_REPO=tap
```

Relocate images...

```shell
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages
```

## Pod Security Policies (TKGs)

```shell
kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
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
    --server harbor.tanzuathome.net \
    --username admin \
    --password Harbor12345 \
    --namespace tap-install \
    --export-to-all-namespaces \
    --yes
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

## Cert Manager Setup

Setup cluster issuer for LetsEncrypt:

```shell
kubectl apply -f cert-manager-setup.yaml
```

Edit `tap-values.yaml` to add the key

```yaml
shared:
  ingress_issuer: "cloudflare-cluster-issuer"
```

Then run

```shell
tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values.yaml -n tap-install
```


## Install Build Service Dependencies

Relocate build service dependencies...

```shell
imgpkg copy \
  -b registry.tanzu.vmware.com/tanzu-application-platform/full-deps-package-repo:${TAP_VERSION} \
  --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-full-deps-packages
```

```shell
tanzu package repository add tap-full-deps-packages \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-full-deps-packages:${TAP_VERSION} \
  --namespace tap-install
```

```shell
tanzu package install full-deps \
  --package full-deps.buildservice.tanzu.vmware.com \
  --version "> 0.0.0" \
  --namespace tap-install \
  --values-file tbs-full-deps-values.yaml
```

## Setup DNS

Get IP address for ingress...

```shell
kubectl get svc -n tanzu-system-ingress
```

Setup DNS A record "*.tap.tanzuathome.net"

## Dev Namespace Provision

```shell
kubectl create ns jgb-dev
```

```shell
kubectl label namespaces jgb-dev apps.tanzu.vmware.com/tap-ns=""
```

```shell
kubectl get secrets,serviceaccount,rolebinding,pods,workload,configmap,limitrange -n jgb-dev
```

Setup RBAC for a developer... (https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.9/tap/namespace-provisioner-legacy-manual-namespace-setup.html#enable-additional-users-with-kubernetes-rbac-1)

```shell
kubectl apply -f dev-role-binding.yaml -n jgb-dev
```


### Setup Scanning Supply Chain

Instructions here: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.9/tap/namespace-provisioner-ootb-supply-chain.html

This should be setup with the namespace provisioner automatically. You can sheck it with the following:

```shell
kubectl get pipeline.tekton.dev,scanpolicies -n jgb-dev
```

### Get Developer Kubeconfig

Retrieve a non-admin Kubceconfig for developer use:

```shell
tanzu cluster kubeconfig get tap-cluster --export-file tap-cluster-dev.kubeconfig
```

## Setup Developer Workstation

1. Install the Tanzu CLI per instructions with TAP (https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.9/tap/install-tanzu-cli.html)
2. Add the pinniped-auth plugin to the Tanzu CLI: `tanzu plugin install pinniped-auth`
3. Merge the Kubeconfig file into .kube/config:
   - if no other contexts, simply copy the contents into that file
   - else, `export KUBECONFIG=<<the file>>`, then `kubectl config view --flatten`, then copy the results into the file  
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
  --param-yaml testing_pipeline_matching_labels='{"apps.tanzu.vmware.com/language": "java"}' \
  --param scanning_source_policy="lax-scan-policy" \
  --param scanning_image_policy="lax-scan-policy" \
  --annotation autoscaling.knative.dev/minScale=1 \
  --build-env "BP_JVM_VERSION=21" \
  --namespace jgb-dev
```

You can change to an old version riddled with CVEs with this command:

```shell
tanzu apps workload apply java-payment-calculator \
  --git-branch "" \
  --git-tag v1.0.0 \
  --build-env "BP_JVM_VERSION=17" \
  --namespace jgb-dev
```

This will change back to the current version:

```shell
tanzu apps workload apply java-payment-calculator \
  --git-branch main \
  --git-tag "" \
  --build-env "BP_JVM_VERSION=21" \
  --namespace jgb-dev
```

```shell
tanzu apps workload create tanzu-java-web-app \
  --git-repo https://github.com/jeffgbutler/tanzu-java-web-app \
  --git-branch main \
  --type web \
  --label app.kubernetes.io/part-of=tanzu-java-web-app \
  --label apps.tanzu.vmware.com/has-tests=true \
  --param-yaml testing_pipeline_matching_labels='{"apps.tanzu.vmware.com/language": "java"}' \
  --param scanning_source_policy="lax-scan-policy" \
  --param scanning_image_policy="lax-scan-policy" \
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
tanzu package installed delete full-deps -n tap-install

tanzu package installed delete tap -n tap-install
```

Uninstall package repositories...

```shell
tanzu package repository delete tanzu-tap-repository -n tap-install

tanzu package repository delete tap-full-deps-packages -n tap-install
```

Delete namespaces...

```shell
kubectl delete ns tap-install
```
