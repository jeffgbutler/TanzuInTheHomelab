# TAP Service Binding Level 4

This page describes the steps required to create a "level 4" service binding in TAP.

A level 4 service binding adds a provisioner to the class claim so service instances can be created on demand.

## Pre-Requisites

1. TAP cluster installed with the `run, iterate, or full` profile installed (TAP 1.5+ required)
2. Namespace `jgb-dev`, setup as a developer namespace in TAP

## Setup

Deploy workloads with no service bindings. This is just to get the initial pipeline to run
so the later steps in the demo go faster.

```shell
tanzu apps workload create spring-sensors-consumer-web \
  --git-repo https://github.com/tanzu-end-to-end/spring-sensors \
  --git-branch rabbit \
  --type web \
  --label app.kubernetes.io/part-of=spring-sensors \
  --annotation autoscaling.knative.dev/minScale=1 \
  -n jgb-dev
```

```shell
tanzu apps workload create spring-sensors-producer \
  --git-repo https://github.com/tanzu-end-to-end/spring-sensors-sensor \
  --git-branch main \
  --type web \
  --label app.kubernetes.io/part-of=spring-sensors \
  --annotation autoscaling.knative.dev/minScale=1 \
  -n jgb-dev
```

## Demonstrate a Level 4 Service Binding

Show out of the box providers MySQL, PostgerSQL, RabbitMQ, Redis...
```shell
tanzu service class list
```

Show parameters for RabbitMQ...
```shell
tanzu service class get rabbitmq-unmanaged
```

Show that no claims are avaiable - this means there are no pre-configured instances...
```shell
tanzu service claimable list --class rabbitmq-unmanaged
```

Create a claim...this will also create a RabbitMQ cluster in a new namespace my-rabbit-xxxxx...
```shell
tanzu service class-claim create my-rabbit --class rabbitmq-unmanaged -n jgb-dev
```

Show the status of the claim - eventually shows a crossplane secret...
```shell
tanzu services class-claims get my-rabbit --namespace jgb-dev
```

Show the cluster...
```shell
kubectl get ns | grep my-rabbit
```

```shell
kubectl get all -n my-rabbit-xxxx
```

Show the secret values...
```shell
kubectl secretdata 00f04jf-fgjshs -n jgb-dev
```

Bind workloads to the service...
```shell
tanzu apps workload update spring-sensors-consumer-web \
  --service-ref="rmq=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:my-rabbit" \
  -n jgb-dev
```

```shell
tanzu apps workload update spring-sensors-producer \
  --service-ref="rmq=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:my-rabbit" \
  -n jgb-dev
```

Show the service bindings
```shell
kubectl get servicebinding -n jgb-dev
```

Hit the app:

https://spring-sensors-consumer-web.jgb-dev.tap.tanzuathome.net/

## Cleanup

Unbind workloads to the service...
```shell
tanzu apps workload update spring-sensors-consumer-web \
  --service-ref="rmq-" \
  -n jgb-dev
```

```shell
tanzu apps workload update spring-sensors-producer \
  --service-ref="rmq-" \
  -n jgb-dev
```

Show the service bindings are gone
```shell
kubectl get servicebinding -n jgb-dev
```

Delete the claim
```shell
tanzu service class-claim delete my-rabbit -n jgb-dev
```

Show the claims are gone
```shell
tanzu service class-claim list -n jgb-dev
```

Show the cluster is gone as well
```shell
kubectl get ns | grep my-rabbit
```
