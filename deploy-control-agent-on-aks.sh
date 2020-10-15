#!/bin/bash

# shellcheck disable=SC2112
function usage() {
  echo "
    Usage: $0 <ControlHub_URL> <SCH_ORG> <SCH_USER> <SCH_USER_PASSWORD> <KUBE_NAMESPACE> <CLUSTER_NAME> <RESOURCE_GROUP>

    Example: $0 https://cloud.streamsets.com testOrg streamsetsUser@testOrg admin1234 namespace clusterName resourceGroup
  "
  # shellcheck disable=SC2242
  exit -1
}

if [ "$#" -ne 7 ]; then
    usage
fi

## Set these variables
# export SCH_AGENT_NAME=streamsets
# export SCH_AGENT_DOCKER_TAG=latest
SCH_URL=$1 # ControlHub_URL
SCH_ORG=$2
SCH_USER=$3
SCH_PASSWORD=$4
KUBE_NAMESPACE=$5
CLUSTER_NAME=$6
RESOURCE_GROUP=$7

## Update kubectl config with connection info
az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME}

## Create Namespace
kubectl create namespace ${KUBE_NAMESPACE}

## Set Context
kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}

## Get auth token fron Control Hub
# SCH_TOKEN=$(curl -s -X POST -d "{\"userName\":\"${SCH_USER}\", \"password\": \"${SCH_PASSWORD}\"}" ${SCH_URL}/security/public-rest/v1/authentication/# login --header "Content-Type:application/json" --header "X-Requested-By:SDC" -c - | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]')
# Above lines commented as SCH_TOKEN is created and exported by parent script


## Use the auth token to get a registration token for a Control Agent
AGENT_TOKEN=$(curl -s -X PUT -d "{\"organization\": \"${SCH_ORG}\", \"componentType\" : \"provisioning-agent\", \"numberOfComponents\" : 1, \"active\" : true}" ${SCH_URL}/security/rest/v1/organization/${SCH_ORG}/components --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}" | jq '.[0].fullAuthToken')

if [ -z "$AGENT_TOKEN" ]; then
  echo "Failed to generate control agent token."
  echo "Please verify you have Provisioning Operator permissions in SCH"
  exit 1
fi

## Store the agent token in a secret
kubectl create secret generic streamsets-creds \
    --from-literal=dpm_agent_token_string=${AGENT_TOKEN}

## create a secret for control agent to use
kubectl create secret generic streamsets-compsecret

## Generate a UUID for the agent
agent_id=$(uuidgen)
echo ${agent_id} > agent.id

## Store connection properties in a configmap for the agent
kubectl create configmap streamsets-config \
    --from-literal=org=${SCH_ORG} \
    --from-literal=sch_url=${SCH_URL} \
    --from-literal=agent_id=${agent_id}

## Create a Service Account to run the Control Agent
kubectl create -f yaml/control-agent-rbac.yaml

## Deploy the control agent
kubectl create -f control-agent.yaml

## Wait until the Control Agent registers itself with Contro Hub
temp_agent_Id=""
while [ -z $temp_agent_Id ]; do
  sleep 10
  temp_agent_Id=$(curl -L "${SCH_URL}/provisioning/rest/v1/dpmAgents?organization=${SCH_ORG}" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}" | jq -r "map(select(any(.id; contains(\"${agent_id}\")))|.id)[]")
done
echo "DPM Agent \"${temp_agent_Id}\" successfully registered with SCH"
