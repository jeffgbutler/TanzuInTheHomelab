# Deploy a Sample for Application Configuration Service

```shell
kubectl apply -f 01_ConfigurationSource.yaml
kubectl apply -f 02_ConfigurationSlice.yaml
kubectl apply -f 03_ResourceClaim.yaml
kubectl apply -f 04_Workload.yaml
```

```shell
kubectl get ConfigurationSource,ConfigurationSlice,Secret,ConfigMap -n jgb-dev
```

```shell
tanzu apps workload create cook \
  --git-repo https://github.com/spring-cloud-services-samples/cook \
  --git-branch main \
  --type web \
  --label app.kubernetes.io/part-of=cook \
  --label apps.tanzu.vmware.com/has-tests=true \
  --annotation autoscaling.knative.dev/minScale=1 \
  --build-env "BP_JVM_VERSION=17" \
  --namespace jgb-dev \
  --env "SPRING_CONFIG_IMPORT=optional:configtree:\${SERVICE_BINDING_ROOT}/spring-properties/" \
  --env "SPRING_CLOUD_ENABLED=false" \
  --env "SPRING_PROFILES_ACTIVE=development" \
  --service-ref "spring-properties=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:cook-config-claim"
```


http://cook.jgb-dev.tap.tanzuathome.net/restaurant
http://cook.jgb-dev.tap.tanzuathome.net/restaurant/secret-menu
http://cook.jgb-dev.tap.tanzuathome.net/restaurant/dessert-menu

