#!/bin/sh

# deploy-traefik-tear-down.sh

# shellcheck disable=SC2112
function usage() {
  echo "
    Usage: $0 <KUBE_NAMESPACE>

    Example: $0 namespace
  "
  # shellcheck disable=SC2242
  exit -1
}

if [ "$#" -ne 1 ]; then
    usage
fi

# Set your namespace
export KUBE_NAMESPACE=$1

## Set Context
kubectl config set-context $(kubectl config current-context) --namespace="${KUBE_NAMESPACE}"

# Cleanup
kubectl delete deployment traefik-ingress-controller-transformer
kubectl delete service traefik-ingress-service-transformer
kubectl delete clusterrole traefik-ingress-controller-transformer
kubectl delete clusterrolebinding traefik-ingress-controller-transformer
kubectl delete serviceaccount traefik-ingress-controller-transformer
kubectl delete configmap traefik-conf-transformer
kubectl delete secret traefik-cert-transformer
rm -rf tls.key
rm -rf tls.crt
