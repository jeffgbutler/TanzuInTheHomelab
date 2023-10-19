# Service Bindings

## Projected Secrets

```shell
kind create cluster

ytt -f podspec.yaml | kapp deploy -y -a pvdemo -f-

kubectl attach -it busybox

cat /bindings/secret1/userId ; echo
cat /bindings/secret1/password ; echo
cat /bindings/secret2/userId ; echo
cat /bindings/secret2/password ; echo

exit

kapp delete -a pvdemo
```

## Overview

Follow example instructions here: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.4/tap/getting-started-consume-services.html

Install RabbitMQ Cluster Operator

```shell
kapp -y deploy --app rmq-operator --file https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml
```

Setup RBAC:

```shell
kubectl apply -f rmq-reader-for-binding-and-claims.yaml
```

Operator Role:

```shell
kubectl apply -f rmq-class.yaml

kubectl create namespace service-instances # Create Namespace for service instances

kubectl apply -f rmq-1-service-instance.yaml # RabbitMQ Create Cluster
# also created a secret rmq-1-default-user...
#
# host: rmq-1.service-instances.svc
# password: fHF2K6rPKnaXdA6aH4LIddAcXi1LJq18
# port: 5672
# provider: rabbitmq
# type: rabbitmq
# username: default_user_icxups7kOFlA0y8Jm9l
#

kubectl apply -f rmq-claim-policy.yaml # Allow services instances to be seen outside the namespace

tanzu services class list # show what types of services are available

tanzu services claimable list --class rabbitmq # show what service instances are available to be claimed

tanzu services class-claim create my-rmq-1 --class rabbitmq -n jgb-dev # create a claim in the dev namespace to some resource from the pool
# Created a SecretExport in the service-instances cluster
# Created a SecretImport in the jgb-dev cluster
# Created a ClassClaim and a ResourceClaim in the dev namespace
# also copied the secret rmq-1-default-user via secretgen-controller

kubectl get SecretImport.secretgen.carvel.dev -n jgb-dev # see the secret import

tanzu services class-claims get rmq-1 --namespace jgb-dev # show status of the claim
```

Developer Role:
```shell
tanzu services class-claims list -n jgb-dev # see what claims are avalable in my namespace

tanzu services class-claims get rmq-1 -n jgb-dev # detailed information

tanzu apps workload create spring-sensors-consumer-web \
  --git-repo https://github.com/tanzu-end-to-end/spring-sensors \
  --git-branch rabbit \
  --type web \
  --label app.kubernetes.io/part-of=spring-sensors \
  --annotation autoscaling.knative.dev/minScale=1 \
  --service-ref="rmq=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:rmq-1" \
  -n jgb-dev

# the service-ref creates a ServiceBinding.servicebinding.io object


tanzu apps workload update spring-sensors-consumer-web \
  --service-ref="rmq-" \
  -n jgb-dev

tanzu apps workload update spring-sensors-consumer-web \
  --service-ref="rmq=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:rmq-1" \
  -n jgb-dev

# look at the projected secrets...

```
