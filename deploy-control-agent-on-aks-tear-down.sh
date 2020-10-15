#!/bin/bash

function usage() {
  echo "
    Usage: $0 <ControlHub_URL> <SCH_ORG> <SCH_USER> <SCH_USER_PASSWORD> <KUBE_NAMESPACE> <CLUSTER_NAME> <RESOURCE_GROUP>

    Example: $0 https://cloud.streamsets.com testOrg streamsetsUser@testOrg admin1234 namespace clusterName resourceGroup
  "
  exit -1
}

if [ "$#" -ne 7 ]; then
    usage
fi

SCH_URL=$1 # ControlHub_URL
SCH_ORG=$2
SCH_USER=$3
SCH_PASSWORD=$4
KUBE_NAMESPACE=$5
CLUSTER_NAME=$6
RESOURCE_GROUP=$7

echo "Getting SCH Token..."
export SCH_TOKEN=$(curl -s -X POST -d "{\"userName\":\"${SCH_USER}\", \"password\": \"${SCH_PASSWORD}\"}" ${SCH_URL}/security/public-rest/v1/authentication/login --header "Content-Type:application/json" --header "X-Requested-By:SDC" -c - | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]')
if [ -z "$SCH_TOKEN" ]; then
  echo "Failed to authenticate with SCH :("
  echo "Please check your username, password, and organization name."
  exit 1
fi

## Update kubectl config with connection info
az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME}

## Set Context
kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}

echo "Deleting StreamSets Agent from SCH..."
agent_id="`cat agent.id`"
# Delete from SCH -> Administration -> Provisioning Agents
curl -X POST -d "[ \"${agent_id}\" ]" ${SCH_URL}/security/rest/v1/organization/${SCH_ORG}/components/deactivate --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}"
curl -X POST -d "[ \"${agent_id}\" ]" ${SCH_URL}/security/rest/v1/organization/${SCH_ORG}/components/delete --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}"
# Delete from SCH -> Execute -> Provisioning Agents
$(curl -X "DELETE" "${SCH_URL}/provisioning/rest/v1/dpmAgent/${agent_id}" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}")
rm -f agent.id

echo "Deleting StreamSets Agent from Kubernetes Cluster..."
kubectl delete deployment streamsets
kubectl delete secrets streamsets-creds
kubectl delete secrets streamsets-compsecret
kubectl delete configmap streamsets-config
kubectl delete serviceaccount streamsets-agent
kubectl delete role streamsets-agent -n ${KUBE_NAMESPACE}
kubectl delete rolebinding streamsets-agent
