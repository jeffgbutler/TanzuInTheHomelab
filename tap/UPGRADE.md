# Upgrade TAP

## Pre-Requisites

- TAP Installed

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
export TAP_VERSION=1.9.1
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
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} \
  --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages
```

```shell
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/full-deps-package-repo:${TAP_VERSION} \
  --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-full-deps-packages
```

## Upgrade TAP

```shell
export KUBECONFIG=$HOME/tap-cluster-kubeconfig-admin.yaml
```

```shell
tanzu package repository update tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages:$TAP_VERSION \
  --namespace tap-install
```

```shell
tanzu package repository update tap-full-deps-packages \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-full-deps-packages:$TAP_VERSION \
  --namespace tap-install
```

```shell
tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values.yaml -n tap-install
```

```shell
tanzu package installed update full-deps \
  --package full-deps.buildservice.tanzu.vmware.com \
  --version "> 0.0.0" \
  --namespace tap-install \
  --values-file tbs-full-deps-values.yaml
```

Find latest Tanzu CLI plugin group:

```shell
tanzu plugin group search --name vmware-tap/default --show-details
```

Update Tanzu CLI Plugins

```shell
tanzu plugin install --group vmware-tap/default:v1.9.1
```