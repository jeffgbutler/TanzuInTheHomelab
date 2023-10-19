# Projected Secrets The Hard Way

## Projected Secrets

```shell
kind create cluster

kapp deploy -a pvdemo -f podspec.yaml

kubectl attach -it busybox

cat /bindings/secret1/userId ; echo
cat /bindings/secret1/password ; echo
cat /bindings/secret2/userId ; echo
cat /bindings/secret2/password ; echo

exit

kapp delete -a pvdemo
```
