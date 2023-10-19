# TAP Service Binding Level 2

This page describes the steps required to create a "level 2" service binding in TAP.

A level 2 service binding allows resources to be in different namespaces. The binding uses a `ResourceClaim`
as the service target rather then the actual service. This allows a level of indirection. But the claim
points to a specific service, so it is still a bit brittle.

An application operator could create the `ResourceClaim` to relieve the infrastructure burden from the developers.

## Pre-Requisites

1. TAP cluster installed with the `run, iterate, or full` profile installed
2. Namespace `jgb-dev`, setup as a developer namespace in TAP
3. Namespace `jgb-dev2`, setup as a developer namespace in TAP
4. Namespace `service-instances` created
5. Rabbit MQ Cluster operator installed:

   ```shell
   kapp -y deploy --app rmq-operator --file https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml
   ```

## Application Operator Tasks

Create a cluster...

```yaml
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: standalone-rabbit
  namespace: service-instances
```

Create claims in two namespaces...

```shell
tanzu services resource-claims create standalone-rabbit \
  --resource-name standalone-rabbit \
  --resource-kind RabbitmqCluster \
  --resource-api-version rabbitmq.com/v1beta1 \
  --resource-namespace service-instances \
  -n jgb-dev
```

```shell
tanzu services resource-claims create standalone-rabbit \
  --resource-name standalone-rabbit \
  --resource-kind RabbitmqCluster \
  --resource-api-version rabbitmq.com/v1beta1 \
  --resource-namespace service-instances \
  -n jgb-dev2
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
  --service-ref="rmq=rabbitmq.com/v1beta1:RabbitmqCluster:jgb-dev-rmq" \
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
    apiVersion: rabbitmq.com/v1beta1
    kind: RabbitmqCluster
    name: jgb-dev-rmq
  workload:
    apiVersion: serving.knative.dev/v1
    kind: Service
    name: spring-sensors-consumer-web
```

You should also see the secret bound into the Knative service...

```shell
kubectl describe service.serving.knative.dev/spring-sensors-consumer-web -n jgb-dev
```

## Cleanup

Remove the service binding...

```shell
tanzu apps workload update spring-sensors-consumer-web \
  --service-ref="rmq-" \
  -n jgb-dev
```

Delete the Rabbit MQ cluster:

```shell
kubectl delete rabbitmqcluster jgb-dev-rmq -n jgb-dev
```
