# Verrazzano Learnings

## Cluster Setup

For this evaluation I used a TCE cluster on vSphere. The TCE cluster has one control plane node, and three worker nodes.
MetalLB is installed to provide load balancing services.

Worker nodes have these characteristics:

- 4 CPU
- 16 GB RAM
- 100 GB Disk

This is more CPU than required for Verrazzano, but other specs are as listed on the Verrazzano site. 

The cluster configuration file is on the TCE bootstrap machine. Cluster created with the following command:

```shell
tanzu cluster create --file verrazzano-cluster.yaml --tkr v1.21.8---vmware.1-tkg.4-tf-v0.11.2
```

Note the downlevel Kubernetes version - Verrazzano does not support Kubernetes 1.22 yet.

Gain access to the cluster:

```shell
tanzu cluster kubeconfig get verrazzano-cluster --admin
```

After installing TCE, setup MetalLB with the following...

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
kubectl apply -f verrazzano-metallb-config.yaml
```


## Verrazzano Installation

I followed the install guide here: https://verrazzano.io/latest/docs/setup/install/installation/

```shell
kubectl apply -f https://github.com/verrazzano/verrazzano/releases/download/v1.2.0/operator.yaml

kubectl -n verrazzano-install rollout status deployment/verrazzano-platform-operator

kubectl -n verrazzano-install get pods
```

(This took just a couiple of minutes to reconcile)

Verrazzano configuration file:

```yaml
apiVersion: install.verrazzano.io/v1alpha1
kind: Verrazzano
metadata:
  name: example-verrazzano
spec:
  profile: dev
```

```shell
kubectl apply -f verrazzano-config.yaml
kubectl wait --timeout=20m --for=condition=InstallComplete verrazzano/example-verrazzano
```

This ran for about 13 minutes and reconciled.

## Installed Componants

Verrazano installed the following:

- Rancher
- Istio
- Nginx for Ingress
- Keycloak
- Cert Manager
- Prometheus
- Graphana
- OpenSearch
- OpenSearch Dashboards

Verrazzano generated certificates for all the consoles (access through nip.io). The console has shows applications
installed and has links to many other consoles:

- Rancher
- Keycloak
- OpenSearch
- Grafana
- Prometheus
- OpenSearch
- Kiali (console for istio)

The UI is a collection of links to open source tools - not really integrated.

## Deploy the Hello Helidon Application

```shell
kubectl create namespace hello-helidon

kubectl label namespace hello-helidon verrazzano-managed=true istio-injection=enabled

kubectl apply -f https://raw.githubusercontent.com/verrazzano/verrazzano/v1.2.0/examples/hello-helidon/hello-helidon-comp.yaml \
  -n hello-helidon

kubectl apply -f https://raw.githubusercontent.com/verrazzano/verrazzano/v1.2.0/examples/hello-helidon/hello-helidon-app.yaml \
  -n hello-helidon

kubectl wait --for=condition=Ready pods --all -n hello-helidon --timeout=300s

kubectl get gateways.networking.istio.io hello-helidon-hello-helidon-appconf-gw -n hello-helidon \
    -o jsonpath='{.spec.servers[0].hosts[0]}'

https://hello-helidon-appconf.hello-helidon.192.168.140.220.nip.io/greet
```


## General Impressions

Verrazzano is a loosely integrated collection of open source stuff and some Oracle exclusive things. The
Oracle exclusive stuff is related to native support for WebLogic and Coherance.

The Verrazano install included the following components:

- Rancher
- Istio
- Nginx for Ingress
- Keycloak
- Cert Manager, External DNS, fluentd, etc.
- Prometheus
- Graphana
- OpenSearch and OpenSearch Dashboards
- WebLogic Operator
- Coherance Operator
- MySQL

They have an interesting multi-cluster story where a central admin cluster can manage multiple workload clusters
from the same console. It's just Rancher giving some visibility to the different clusters and the Verazzano operator pushing
workloads around. It does include consolidated metrics from the different clusters.

It is installed on an existing Kubernetes cluster or clusters and does not include anything for managing the cluster
lifecycles. Rancher is embedded, but more in the sense that Rancher can give a view of all the Verrazzano clusters
(kind of like the functionality of TMC with attached clusters - or more like the functionality that we used to show
with Octant).

There are 8 different consoles installed for various different tools. There is no SSO between the various
consoles, a few of them share a password, but others have unique passwords.

Changing a password involves using the Keycloak console as well as manually updating secrets (both steps are required).

Telemetry/Observability is all open source and local only. This could be imported into TO, or into another
locally managed Prometheus.

The Coherance operator and the WebLogic operator were both installed and Verrazzano has built-in support for
moving workloads off WebLogic (this means running WebLogic in a container). There is a manual page
for lifting and shifting WebLogic workloads into Verrazzano
(https://verrazzano.io/latest/docs/guides/lift-and-shift/lift-and-shift/).
**If I had to speculate, I would guess this is the primary use case for Verrazzano.**

Verrazzano does not bundle a container registry like Harbor.

Verrazzano has no image build/scan functionality - they specifically say that image building is outside of the platform.
There is a toolkit for containerizing WebLogic workloads (https://github.com/oracle/weblogic-image-tool) See my above comment
regarding WebLogic as the primary use case for Verrazzano.

Verrazzano uses the Open Application Model (OAM) for deployments. OAM is a Microsoft/Alibaba thing so it has some
legs for sure. It's in the same problem space as Helm and our Kapp controller. Not much to differentiate these
different stratregies except tooling and community adoption. I will say that Verrazzano doesn't offer much help
with OAM beyond "wall of YAML" examples for creating workloads.

The Day-2 story isn't great, but not terrible either. You can do upgrades of all the installed Verrazanao componants
with a single "kubectl patch" command. But again, there is no help for managing the lifecycle of Kubernetes itself.

They do not bundle Knative and have no integrated support for functions or event based systems.

There's nothing like App Live View.

There's nothing like TAP GUI.

There's nothing like App Accelerators.

There are no IDE integrations.

There's nothing like the tanzu CLI - it's all kubectl and YAML that is specific to all the different tools.
