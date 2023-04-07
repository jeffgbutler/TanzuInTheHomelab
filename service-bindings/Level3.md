# TAP Service Binding Level 3

This page describes the steps required to create a "level 3" service binding in TAP.

A level 3 service binding allows resources to be in different namespaces. The binding uses a `ClassClaim`
as the service target rather then the actual service. This allows a level of indirection. The class claim points to
a pre-provisioned service instance from a pool.

An application operator could create the `ClassClaim` to relieve the infrastructure burden from the developers.

A distinct advantage of this claim is that the name of the claim does not need to match the name of the
claimed resource. This allows us to create different pools of resources in different environments. For example,
on a development cluster we might want to use small non-persistent services for development and testing, but
on a production cluster we would want high availability. With class claims the developer doesn't need to
be concerned with any of this - they only need to know the name of the claim. The claim itself could be
configured differently on different clusters.

## Pre-Requisites

1. TAP cluster installed with the `run, iterate, or full` profile installed
2. Namespace `jgb-dev`, setup as a developer namespace in TAP
3. Rabbit MQ Cluster operator installed:

   ```shell
   kapp -y deploy --app rmq-operator --file https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml
   ```

4. Services Instances provisioned and configured:

   ```shell
   kapp -y deploy --app rmq-service-configuration --file level3Configuration/.
   ```

## Application Operator Tasks

Display configured classes:
```shell
tanzu services classes list
```

Show large clusters available:
```shell
tanzu services claimable list --class rabbitmq-preprovisioned-large
```

Show small clusters available:
```shell
tanzu services claimable list --class rabbitmq-preprovisioned-small
```

Create a claim:
```shell
tanzu services class-claim create rmq-for-sensors --class rabbitmq-preprovisioned-small -n jgb-dev
```

Check status of claim:
```shell
tanzu services class-claims get rmq-for-sensors --namespace jgb-dev
```

Show that the number of clusters available in the pool has been reduced:
```shell
tanzu services claimable list --class rabbitmq-preprovisioned-small
```

Show objects created in the namespace:
```shell
kubectl get Secret,ClassClaim,SecretImport.secretgen.carvel.dev -n jgb-dev
```

Show class claim details:
```shell
kubectl describe ClassClaim rmq-for-sensors -n jgb-dev
```

Get binding name:
```shell
tanzu services class-claims get rmq-for-sensors -n jgb-dev
```

## Developer Tasks

Create a workload...

```shell
tanzu apps workload create spring-sensors-consumer-web \
  --git-repo https://github.com/tanzu-end-to-end/spring-sensors \
  --git-branch rabbit \
  --type web \
  --label app.kubernetes.io/part-of=spring-sensors \
  --annotation autoscaling.knative.dev/minScale=1 \
  --service-ref="rmq=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:rmq-for-sensors" \
  -n jgb-dev
```

Once the workload reconciles, your should see a ServiceBinding...

```shell
kubectl get servicebinding.servicebinding.io/spring-sensors-consumer-web-rmq -n jgb-dev -o yaml
```

The basics of the service binding look like this...

```yaml
apiVersion: servicebinding.io/v1beta1
kind: ServiceBinding
metadata:
  name: spring-sensors-consumer-web-rmq
  namespace: jgb-dev
spec:
  name: rmq
  service:
    apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ClassClaim
    name: rmq-for-sensors
  workload:
    apiVersion: serving.knative.dev/v1
    kind: Service
    name: spring-sensors-consumer-web
```

You should also see the secret bound into the Knative service...

```shell
kubectl describe service.serving.knative.dev/spring-sensors-consumer-web -n jgb-dev
```

## Release the Claim

Remove the service binding...

```shell
tanzu apps workload update spring-sensors-consumer-web \
  --service-ref="rmq-" \
  -n jgb-dev
```

Release the claim...
```shell
tanzu services class-claim delete rmq-for-sensors -n jgb-dev
```

Show the queue is now claimable:
```shell
tanzu services claimable list --class rabbitmq-preprovisioned-small
```

# Cleanup

```shell
kapp delete -a rmq-service-configuration
```

```shell
kapp delete -a rmq-operator
```
