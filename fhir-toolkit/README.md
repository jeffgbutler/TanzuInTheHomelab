```shell
tanzu service class get postgresql-unmanaged

tanzu service class-claim create fhir-postgres --class postgresql-unmanaged -n jgb-dev

tanzu apps workload create fhir \
  --image hapiproject/hapi:latest \
  --type web \
  --label app.kubernetes.io/part-of=fhir \
  --annotation autoscaling.knative.dev/minScale=1 \
  --service-ref="postgres=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:fhir-postgres" \
  -n jgb-dev

tanzu apps workload create fhir \
  --image docker.io/hapiproject/hapi:latest \
  --type server \
  --label app.kubernetes.io/part-of=fhir \
  --service-ref="postgres=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:fhir-postgres" \
  -n jgb-dev


tanzu apps workload create fhir \
  --git-repo https://github.com/hapifhir/hapi-fhir-jpaserver-starter \
  --git-tag v6.4.0 \
  --type server \
  --label app.kubernetes.io/part-of=fhir \
  --build-env "BP_JVM_VERSION=17" \
  --build-env "spring.profiles.active=boot" \
  --service-ref="postgres=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:fhir-postgres" \
  -n jgb-dev

services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:fhir-postgres

```
