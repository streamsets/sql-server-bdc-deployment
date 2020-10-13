#!/bin/bash
set -x # Option to show script debug info in console

function usage() {
  echo "
    Usage: $0 <SCH_USER> <SCH_USER_PASSWORD>

    Example: $0 streamsetsUser@testOrg admin1234
  "
  # shellcheck disable=SC2242
  exit -1
}

if [ "$#" -ne 2 ]; then
    usage
fi

SCH_URL=https://cloud.streamsets.com # ControlHub_URL
SCH_ORG=testOrg
SCH_USER=$1
SCH_PASSWORD=$2
KUBE_NAMESPACE=streamsets
CLUSTER_NAME=kubcluster
RESOURCE_GROUP=sqlbdcgroup

SCH_DEPLOYMENT_NAME="Authoring SDC"
SCH_DEPLOYMENT_LABELS=auth-sdc
SDC_REPLICAS=1

echo "Getting SCH Token..."
export SCH_TOKEN=$(curl -s -X POST -d "{\"userName\":\"${SCH_USER}\", \"password\": \"${SCH_PASSWORD}\"}" ${SCH_URL}/security/public-rest/v1/authentication/login --header "Content-Type:application/json" --header "X-Requested-By:SDC" -c - | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]')
if [ -z "$SCH_TOKEN" ]; then
  echo "Failed to authenticate with SCH :("
  echo "Please check your username, password, and organization name."
  exit 1
fi

dep_id="`cat dep.id`"
echo "Stopping SDC deployment in SCH..."
$(curl -X "POST" -d "[ \"${dep_id}\" ]" "${SCH_URL}/provisioning/rest/v1/deployments/stopDeployments" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}")
# sleep for 1 minute to give time to SCH to stop de deployment
sleep 60
# Stop might not work for now. Pending resolution of JIRA issues DPM-6764
# Acknowledge errors if any when trying to stop deployment from SCH as we will anyway delete it with kubectl
$(curl -X "POST" -d "[\"${dep_id}\"]" "${SCH_URL}/provisioning/rest/v1/deploymens/acknowledgeErrors" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}")
echo "Deleting SDC deployment in SCH..."
$(curl -X "DELETE" "${SCH_URL}/provisioning/rest/v1/deployment/${dep_id}" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}")
rm -rf dep.id

kubectl delete service authoring
kubectl delete ingresses.extensions authoring-sdc
kubectl delete deployment authoring-datacollector-deployment
kubectl delete secrets streamsets-sql-server-bdc-resources

echo "Deleting Traefik ingress controller..."
pushd ./traefik
./deploy-traefik-tear-down.sh ${KUBE_NAMESPACE}
popd

echo "Deleting StreamSets Agent..."
./deploy-control-agent-on-aks-tear-down.sh ${SCH_URL} ${SCH_ORG} ${SCH_USER} ${SCH_PASSWORD} ${KUBE_NAMESPACE} ${CLUSTER_NAME} ${RESOURCE_GROUP}

echo "Deleting StreamSets Transformer..."
pushd ./transformer
./deploy-transformer-on-aks-tear-down.sh ${SCH_URL} ${SCH_ORG} ${SCH_USER} ${SCH_PASSWORD} ${KUBE_NAMESPACE}
popd

echo "Successfully deleted all corresponding objects"
