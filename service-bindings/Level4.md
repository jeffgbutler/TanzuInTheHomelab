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

tanzu apps workload create spring-sensors-producer \
  --git-repo https://github.com/tanzu-end-to-end/spring-sensors-sensor \
  --git-branch main \
  --type web \
  --label app.kubernetes.io/part-of=spring-sensors \
  --annotation autoscaling.knative.dev/minScale=1 \
  -n jgb-dev
```

## Demonstrate a Level 4 Service Binding

```shell
# show out of the box providers MySQL, PostgerSQL, RabbitMQ, Redis
tanzu service class list

# show parameters for RabbitMQ
tanzu service class get rabbitmq-unmanaged

# show that no claims are avaiable - this means there are no pre-configured instances
tanzu service claimable list --class rabbitmq-unmanaged

# create a claim...this will also create a RabbitMQ cluster in a new namespace my-rabbit-xxxxx
tanzu service class-claim create my-rabbit --class rabbitmq-unmanaged -n jgb-dev

# show the status of the claim - eventually shows a crossplane secret
tanzu services class-claims get my-rabbit --namespace jgb-dev

# show the secret values...
kubectl secretdata 00f04jf-fgjshs -n jgb-dev

# bind workloads to the service...
tanzu apps workload update spring-sensors-consumer-web \
  --service-ref="rmq=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:my-rabbit" \
  -n jgb-dev

tanzu apps workload update spring-sensors-producer \
  --service-ref="rmq=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:my-rabbit" \
  -n jgb-dev

# show the service bindings
kubectl get servicebinding -n jgb-dev
```

Hit the app:

https://spring-sensors-consumer-web.jgb-dev.tap.tanzuathome.net/

## Cleanup

```shell
# unbind workloads to the service...
tanzu apps workload update spring-sensors-consumer-web \
  --service-ref="rmq-" \
  -n jgb-dev

tanzu apps workload update spring-sensors-producer \
  --service-ref="rmq-" \
  -n jgb-dev

# show the service bindings are gone
kubectl get servicebinding -n jgb-dev

# delete the claim
tanzu service class-claim delete my-rabbit -n jgb-dev

# show the claims are gone
tanzu service class-claim list -n jgb-dev

# show the cluster is gone as well
kubectl get ns | grep my-rabbit
```
