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
export TAP_VERSION=1.5.6
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
tanzu package repository update tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages:$TAP_VERSION \
  --namespace tap-install
```

```shell
tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values.yaml -n tap-install
```

Find Build Service Version...
```shell
tanzu package available list buildservice.tanzu.vmware.com --namespace tap-install
```

Relocate build service dependenciaes...
```shell
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/full-tbs-deps-package-repo:1.10.13 \
  --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tbs-full-deps
```

```shell
tanzu package repository update tbs-full-deps-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tbs-full-deps:1.10.13 \
  --namespace tap-install
```

```shell
tanzu package installed update full-tbs-deps -p full-tbs-deps.tanzu.vmware.com -v 1.10.13 -n tap-install
```
