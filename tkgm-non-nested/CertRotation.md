Check certificate expiration:

# Renew Certificates

https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/2.2/using-tkg-22/workload-clusters-secret.html#renew-certificates


```shell
kubectl get nodes \
-o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' \
-l node-role.kubernetes.io/master= > nodes

for i in `cat nodes`; do
   printf "\n######\n"
   ssh -o "StrictHostKeyChecking=no" -q capv@$i hostname
   ssh -o "StrictHostKeyChecking=no" -q capv@$i sudo kubeadm certs check-expiration
done;
```

```shell
kubectl get nodes \
-o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' \
-l node-role.kubernetes.io/control-plane= > nodes

for i in `cat nodes`; do
   printf "\n######\n"
   ssh -o "StrictHostKeyChecking=no" -q capv@$i hostname
   ssh -o "StrictHostKeyChecking=no" -q capv@$i sudo kubeadm certs check-expiration
done;
```
