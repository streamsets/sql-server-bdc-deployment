# StreamSets SQL Server BDC Deployment Guide

This guide describes how to deploy a StreamSets Agent and Transformer, register it in Control Hub and deploy a 
Data Collector Kubernetes Deployment able to connect to a SQL Server BDC cluster

## Steps

### Setup

1. Open streamsets-bdc-deployment-all-in-one.sh file

2. Change next variables values according to the environment to use
   * SCH_URL: Control Hub URL
   * SCH_ORG: Control Hub organization
   * KUBE_NAMESPACE: Kubernetes namespace
   * CLUSTER_NAME: Kubernetes cluster name
   * RESOURCE_GROUP: Azure resource group

3. Run streamsets-bdc-deployment-all-in-one.sh passing as arguments Control Hub user and Control Hub user password. 
Example: ./streamsets-bdc-deployment-all-in-one.sh username@organizationname password
    * If asked to overwrite an object in kubeconfig file just say yes ('y')
    * If everything runs as expected you should se the message: "Deployment Successful"

### Teardown

1. Open streamsets-bdc-deployment-all-in-one-tear-down.sh file

2. Change next variables values according to the environment to use
   * SCH_URL: Control Hub URL
   * SCH_ORG: Control Hub organization
   * KUBE_NAMESPACE: Kubernetes namespace
   * CLUSTER_NAME: Kubernetes cluster name
   * RESOURCE_GROUP: Azure resource group

3. Run streamsets-bdc-deployment-all-in-one-tear-down.sh passing as arguments Control Hub user and Control Hub user password. 
Example: ./streamsets-bdc-deployment-all-in-one-tear-down.sh username@organizationname password
    * If asked to overwrite an object in kubeconfig file just say yes ('y')
    * If everything runs as expected you should se the message: "Successfully deleted all corresponding objects"
