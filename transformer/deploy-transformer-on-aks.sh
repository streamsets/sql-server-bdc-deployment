#!/bin/sh

# Copyright 2019 StreamSets Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# shellcheck disable=SC2112
function usage() {
  echo "
    Usage: $0 <ControlHub_URL> <SCH_ORG> <SCH_USER> <SCH_USER_PASSWORD> <KUBE_NAMESPACE>

    Example: $0 https://cloud.streamsets.com testOrg streamsetsUser@testOrg admin1234 namespace
  "
  # shellcheck disable=SC2242
  exit -1
}

if [ "$#" -ne 5 ]; then
    usage
fi

## Set these variables
SCH_URL=$1 # ControlHub_URL
SCH_ORG=$2
SCH_USER=$3
SCH_PASSWORD=$4
KUBE_NAMESPACE=$5
BDC_KUBE_NAMESPACE="mssql-cluster"

## Set Context
# shellcheck disable=SC2046
kubectl config set-context $(kubectl config current-context) --namespace="${KUBE_NAMESPACE}"

## Get auth token fron Control Hub
echo "Getting SCH Token..."
export SCH_TOKEN=$(curl -s -X POST -d "{\"userName\":\"${SCH_USER}\", \"password\": \"${SCH_PASSWORD}\"}" ${SCH_URL}/security/public-rest/v1/authentication/login --header "Content-Type:application/json" --header "X-Requested-By:SDC" -c - | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]')
if [ -z "$SCH_TOKEN" ]; then
  >&2 echo "Failed to authenticate with SCH :("
  >&2 echo "Please check your username, password, and organization name."
  exit 1
fi

## Use the auth token to get a registration token for a Control Agent
echo "Getting transformer Token..."
TRANSFORMER_TOKEN=$(curl -s -X PUT -d "{\"organization\": \"${SCH_ORG}\", \"componentType\" : \"transformer\", \"numberOfComponents\" : 1, \"active\" : true}" ${SCH_URL}/security/rest/v1/organization/${SCH_ORG}/components --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}" | jq '.[0].fullAuthToken' | tr -d '"')

if [ -z "$TRANSFORMER_TOKEN" ]; then
  >&2 echo "Failed to generate transformer token."
  >&2 echo "Please verify you have Auth Token Generator permission in StreamSets Control Hub"
  exit 1
fi

## Store the Transformer token in a secret
kubectl create secret generic streamsets-transformer-creds \
    --from-literal=transformer_token_string="${TRANSFORMER_TOKEN}"

## Generate a UUID for the transformer
transformer_id=$(docker run --rm andyneff/uuidgen uuidgen -t)
echo "${transformer_id}" > transformer.id

echo "Deploying traefik ingress controller for transformer..."
pushd ./traefik-transformer
./deploy-traefik.sh "${KUBE_NAMESPACE}"
popd

echo "Waiting until traefik is assigned an external IP (this can take a minute)..."
external_ip=""
while true; do
    #This section is a little messy because some K8s implementations return the address in a field named 'ip' and others in field named 'hostname"
    ingress=$(kubectl get svc traefik-ingress-service-transformer -o json)
    ingress_host=$(echo "$ingress" | jq -r 'select(.status.loadBalancer.ingress != null) | .status.loadBalancer.ingress[].hostname')
    if [ -n "${ingress_host}" -a "${ingress_host}" != "null" ];
    then
      external_ip=$ingress_host
      break
    else
      ingress_ip=$(echo "$ingress" | jq -r 'select(.status.loadBalancer.ingress != null) | .status.loadBalancer.ingress[].ip')
      if [ -n "${ingress_ip}" -a "${ingress_ip}" != "null" ];
      then
        external_ip=$ingress_ip
        break
      fi
    fi
    sleep 10
done
echo "External Endpoint to Access Authoring Datacollector : ${external_ip}"
export external_ip

## Store connection properties in a configmap for the transformer
kubectl create configmap streamsets-transformer-config \
    --from-literal=org="${SCH_ORG}" \
    --from-literal=sch_url="${SCH_URL}" \
    --from-literal=transformer_id="${transformer_id}" \
    --from-literal=transformer_external_url=https://"${external_ip}"

## Create a service account to run the transformer
kubectl create serviceaccount streamsets-transformer --namespace="${KUBE_NAMESPACE}"

## Create a role for the service account with permissions to
## create pods (among other things)
kubectl create role streamsets-transformer \
    --verb=get,list,watch,create,update,delete,patch \
    --resource=pods,secrets,configmaps,replicasets,ingresses,services \
    --namespace="${KUBE_NAMESPACE}"

## Bind the role to the service account
kubectl create rolebinding streamsets-transformer \
    --role=streamsets-transformer \
    --serviceaccount="${KUBE_NAMESPACE}":streamsets-transformer \
    --namespace="${KUBE_NAMESPACE}"

## Extract certificate from SQL Server 2019 Big Data Cluster Gateway IP
gatewayIp=$(kubectl get services --field-selector metadata.name=gateway-svc-external --namespace="${BDC_KUBE_NAMESPACE}" -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
gatewayPort=$(kubectl get services --field-selector metadata.name=gateway-svc-external --namespace="${BDC_KUBE_NAMESPACE}" -o jsonpath="{.items[0].spec.ports[0].port}")
echo | openssl s_client -connect "$gatewayIp":"$gatewayPort" | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > gateway.crt

## Import gateway HTTPs certificate in to the truststore.jks
keytool -import -file gateway.crt -trustcacerts -noprompt -alias SQLServerCA -storepass password -keystore truststore.jks

## Extract certificate from Minikube Ingress IP
echo | openssl s_client -connect "$external_ip":443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ingress.crt

## Import Minikube Ingress HTTPs certificate in to the truststore.jks
keytool -import -file ingress.crt -trustcacerts -noprompt -alias IngressCA -storepass password -keystore truststore.jks

## Copy the CA certs from jre/lib/security/cacerts to etc/truststore.jks
keytool -importkeystore -srckeystore "$JAVA_HOME"/jre/lib/security/cacerts -srcstorepass changeit -destkeystore truststore.jks -deststorepass password

## Store the truststore.jks in a secret
kubectl create secret generic streamsets-transformer-cert --namespace="${KUBE_NAMESPACE}" --from-file=truststore.jks

## Deploy the Transformer
kubectl create -f transformer.yaml

echo "Running Transformer Instance - https://${external_ip}. Open this URL in the browser and accept the browser warning before accessing this in Control Hub"
