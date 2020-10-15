#!/bin/bash

# deploy-traefik.sh

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
kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}

# Create a service account
kubectl create serviceaccount traefik-ingress-controller --namespace=${KUBE_NAMESPACE}

# Create a cluster role
kubectl create clusterrole traefik-ingress-controller \
    --verb=get,list,watch \
    --resource=endpoints,ingresses.extensions,services,secrets

# Bind the service account to the role
kubectl create clusterrolebinding traefik-ingress-controller \
    --clusterrole=traefik-ingress-controller \
    --serviceaccount=${KUBE_NAMESPACE}:traefik-ingress-controller

# Generate a self signed certificate
openssl req -newkey rsa:2048 \
    -nodes \
    -keyout tls.key \
    -x509 \
    -days 365 \
    -out tls.crt \
    -subj "/C=US/ST=California/L=San Francisco/O=My Company/CN=mycompany.com" \
    -extensions traefik_ext \
    -config myconfig.cnf

# Store the cert in a secret
kubectl create secret generic traefik-cert --namespace=${KUBE_NAMESPACE} \
    --from-file=tls.crt \
    --from-file=tls.key

# Load the traefik.toml file into a configmap
kubectl create configmap traefik-conf --from-file=traefik.toml --namespace=${KUBE_NAMESPACE}

# Create traefik service
kubectl create -f traefik-dep.yaml --namespace=${KUBE_NAMESPACE}
