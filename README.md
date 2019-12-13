# StreamSets SQL Server BDC Deployment Guide

This guide describes how to deploy a StreamSets Agent, register it in ControlHub and deploy a DataCollector Kubernetes 
Deployment able to connect to a SQL Server BDC cluster

## Steps

### Setup

1. Open streamsets-bdc-deployment-all-in-one.sh file

2. Change next variables values according to the environment to use
   * SCH_URL: ControlHub URL
   * SCH_ORG: ControlHub organization
   * KUBE_NAMESPACE: Kubernetes namespace
   * CLUSTER_NAME: Kubernetes cluster name
   * RESOURCE_GROUP: Azure resource group

3. Run streamsets-bdc-deployment-all-in-one.sh passing as arguments ControlHub user and ControlHub user password. 
Example: ./sdc-bdc-deployment-all-in-one.sh username@organizationname password
    * If asked to overwrite an object in kubeconfig file just say yes ('y')
    * If everything runs as expected you should se the message: "Deployment Successful"

### Teardown

1. Open streamsets-bdc-deployment-all-in-one-tear-down.sh file

2. Change next variables values according to the environment to use
   * SCH_URL: ControlHub URL
   * SCH_ORG: ControlHub organization
   * KUBE_NAMESPACE: Kubernetes namespace
   * CLUSTER_NAME: Kubernetes cluster name
   * RESOURCE_GROUP: Azure resource group

3. Run streamsets-bdc-deployment-all-in-one-tear-down.sh passing as arguments ControlHub user and ControlHub user password. 
Example: ./sdc-bdc-deployment-all-in-one-tear-down.sh username@organizationname password
    * If asked to overwrite an object in kubeconfig file just say yes ('y')
    * If everything runs as expected you should se the message: "Successfully deleted all corresponding objects"
