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

# Please read the StreamSets EULA https://streamsets.com/eula.
# If you agree please change the following line to ACCEPT_EULA=Y
ACCEPT_EULA=Y
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

if [ "${ACCEPT_EULA}" != "Y" ]; then
  echo "Please read the StreamSets EULA https://streamsets.com/eula and accept it by setting ACCEPT_EULA=Y"
  exit 1
fi

echo "Getting SCH Token..."
export SCH_TOKEN=$(curl -s -X POST -d "{\"userName\":\"${SCH_USER}\", \"password\": \"${SCH_PASSWORD}\"}" ${SCH_URL}/security/public-rest/v1/authentication/login --header "Content-Type:application/json" --header "X-Requested-By:SDC" -c - | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]')
if [ -z "$SCH_TOKEN" ]; then
  echo "Failed to authenticate with SCH :("
  echo "Please check your username, password, and organization name."
  exit 1
fi

echo "Creating  Namespace and deploying StreamSets Agent..."
./deploy-control-agent-on-aks.sh ${SCH_URL} ${SCH_ORG} ${SCH_USER} ${SCH_PASSWORD} ${KUBE_NAMESPACE} ${CLUSTER_NAME} ${RESOURCE_GROUP}
agent_id="`cat agent.id`"

echo "Deploying traefik ingress controller..."
pushd ./traefik
./deploy-traefik.sh ${KUBE_NAMESPACE}
popd

echo "Waiting until traefik is assigned an external IP (this can take a minute)..."
external_ip=""
#while [ -z $external_ip ]; do
while [ 1 ]; do
    #This section is a little messy because some K8s implementations return the address in a field named 'ip' and others in field named 'hostname"
    ingress=$(kubectl get svc traefik-ingress-service -o json)
    ingress_host=$(echo $ingress | jq -r 'select(.status.loadBalancer.ingress != null) | .status.loadBalancer.ingress[].hostname')
    if [ -n "${ingress_host}" -a "${ingress_host}" != "null" ];
    then
      external_ip=$ingress_host
      break
    else
      ingress_ip=$(echo $ingress | jq -r 'select(.status.loadBalancer.ingress != null) | .status.loadBalancer.ingress[].ip')
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

echo "Creating Authoring Datacollector Service"
kubectl create -f authoring-sdc-svc.yaml -n ${KUBE_NAMESPACE}

echo "Deploying Authoring datacollector deployment"
rm -rf ${PWD}/_tmp_deployment.yaml
cat ./sdc-sql-server-bdc-deployment_init-containers.yaml | envsubst > ${PWD}/_tmp_deployment.yaml

kubectl get svc -n ${KUBE_NAMESPACE} -o json | jq -r '.items[] | select(.status.loadBalancer.ingress[0].ip!=null) | {"serviceName": .metadata.name, "ip":.status.loadBalancer.ingress[0].ip, "port":.spec.ports[0].port}' > ${PWD}/sql-server-ip-and-port.json

kubectl create secret generic streamsets-sql-server-bdc-resources --namespace=${KUBE_NAMESPACE} --from-file=${PWD}/sql-server-ip-and-port.json
rm -rf ${PWD}/sql-server-ip-and-port.json

# Create Deployment in SCH
DEP_ID=$(curl -s -X PUT -d "{\"name\":\"${SCH_DEPLOYMENT_NAME}\",\"description\":\"Authoring sdc\",\"labels\":[\"${SCH_DEPLOYMENT_LABELS}\"],\"numInstances\":${SDC_REPLICAS},\"spec\":\"$(cat ${PWD}/_tmp_deployment.yaml | sed -e :a -e '$!N;s/\n/\\\n/;ta')\",\"agentId\":\"${agent_id}\"}" "${SCH_URL}/provisioning/rest/v1/deployments" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}" | jq -r '.id') || { echo 'ERROR: Failed to create deployment in SCH' ; exit 1; }
echo ${DEP_ID} > dep.id

# Start Deployment in SCH
curl -s -X POST "${SCH_URL}/provisioning/rest/v1/deployment/${DEP_ID}/start?dpmAgentId=${agent_id}" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${SCH_TOKEN}" || { echo 'ERROR: Failed to start deployment in SCH' ; exit 1; }
echo "Successfully started deployment \"authoring-datacollector-deployment\" on Agent \"${agent_id}\""

echo "Deleting temporary files..."
rm -rf ${PWD}/_tmp_deployment.yaml

echo "Deploying StreamSets Transformer..."
pushd ./transformer
./deploy-transformer-on-aks.sh ${SCH_URL} ${SCH_ORG} ${SCH_USER} ${SCH_PASSWORD} ${KUBE_NAMESPACE}
popd

echo "Deployment Successful"
