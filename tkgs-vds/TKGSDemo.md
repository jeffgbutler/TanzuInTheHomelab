# Demo of TKGs

## Login to the Supervisor Cluster

```shell
kubectl vsphere login --server 192.168.139.3 -u administrator@vsphere.local --insecure-skip-tls-verify
kubectl config use-context test-namespace
```

## Interesting Commands:

1. `kubectl config get-contexts` will show two contexts - the IP, and demo-namespace
1. `kubectl config use-context test-namespace`
1. `kubectl describe virtualmachineclasses` - shows virtual machine classes available
1. `kubectl describe ns test-namespace` - shows storage classes available
1. `kubectl describe TkgServiceConfiguration` - show/edit global parameters for TKGS
1. `kubectl get storageclasses` - also shows storage classes
1. `kubectl get TanzuKubernetesReleases` - shows what Kubernetes versions are available
1. `kubectl get VirtualMachineImages` - shows virtual machine images which is similar to Kubernetes versions, but doesn't show upgrade paths
1. `kubectl vsphere logout`

## Create a Cluster:

1. `kubectl apply -f 00-createcluster.yaml` (took about 25 minutes)
1. `kubectl get TanzuKubernetesClusters` watch progress of cluster creation

## Security

You have very little authority in the supervisor cluster - need to get into your own cluster before you can really do
anything. You can see this with `kubectl get clusterroles` - not authorized

Login to the cluster you created:

```
kubectl vsphere logout

kubectl vsphere login --server 192.168.139.3 --tanzu-kubernetes-cluster-namespace test-namespace \
  --tanzu-kubernetes-cluster-name tap-cluster -u administrator@vsphere.local \
  --insecure-skip-tls-verify

kubectl config use-context tap-cluster
```

Show roles and role bindings:
- `kubectl get clusterroles`
- `kubectl get clusterrolebindings`

## Deployments

On vSphere with Tanzu we need to give permission to the default service account for deployments to work.

Run `kubectl apply -f 01-deployment.yaml`

Run `kubectl describe rs` to show the security error

Run this to fix the error:

```shell
kubectl create clusterrolebinding default-tkg-admin-privileged-binding \
  --clusterrole=psp:vmware-system-privileged \
  --group=system:authenticated
```

Run `kubectl describe rs` to show things working

## Load Balancer Service

Run `kubectl apply -f 02-loadbalancerservice.yaml` to create the service

Run `kubectl get svc` to see the IP address created from HA Proxy

Navigate to the IP Address
