#!/bin/bash

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

echo "Getting SCH Token..."
export SCH_TOKEN=$(curl -s -X POST -d "{\"userName\":\"${SCH_USER}\", \"password\": \"${SCH_PASSWORD}\"}" ${SCH_URL}/security/public-rest/v1/authentication/login --header "Content-Type:application/json" --header "X-Requested-By:SDC" -c - | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]')
if [ -z "$SCH_TOKEN" ]; then
  >&2 echo "Failed to authenticate with SCH :("
  >&2 echo "Please check your username, password, and organization name."
  exit 1
fi

## Set Context
kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}

echo "Deleting StreamSets Transformer from SCH..."
transformer_id="`cat transformer.id`"
# Delete from SCH -> Administration -> Transformers
curl -X POST -d "[ \"${transformer_id}\" ]" ${SCH_URL}/security/rest/v1/organization/${SCH_ORG}/components/deactivate --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}"
curl -X POST -d "[ \"${transformer_id}\" ]" ${SCH_URL}/security/rest/v1/organization/${SCH_ORG}/components/delete --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}"
# Delete from SCH -> Execute -> Transformers
$(curl -X "DELETE" "${SCH_URL}/jobrunner/rest/v1/sdc/${transformer_id}" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}")
rm -f transformer.id

rm -f gateway.crt
rm -f ingress.crt
rm -f truststore.jks

echo "Deleting Traefik ingress controller..."
pushd ./traefik-transformer
./deploy-traefik-tear-down.sh ${KUBE_NAMESPACE}
popd

echo "Deleting StreamSets Transformer from Kubernetes Cluster..."
kubectl delete deployment streamsets-transformer
kubectl delete secrets streamsets-transformer-creds
kubectl delete secrets streamsets-transformer-cert
kubectl delete configmap streamsets-transformer-config
kubectl delete serviceaccount streamsets-transformer
kubectl delete role streamsets-transformer -n "${KUBE_NAMESPACE}"
kubectl delete rolebinding streamsets-transformer
kubectl delete service streamsets-transformer
kubectl delete ingresses.extensions streamsets-transformer
