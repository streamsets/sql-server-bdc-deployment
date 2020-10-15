#!/bin/bash

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
kubectl delete deployment traefik-ingress-controller
kubectl delete service traefik-ingress-service
kubectl delete clusterrole traefik-ingress-controller
kubectl delete clusterrolebinding traefik-ingress-controller
kubectl delete serviceaccount traefik-ingress-controller
kubectl delete configmap traefik-conf
kubectl delete secret traefik-cert
rm -rf tls.key
rm -rf tls.crt
