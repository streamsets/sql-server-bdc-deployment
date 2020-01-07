# StreamSets SQL Server BDC Deployment Script

The StreamSets SQL Server BDC deployment script deploys a Control Hub Provisioning Agent on a Kubernetes cluster and provisions one Data Collector and one Transformer that are enabled to connect to SQL Server 2019 Big Data Cluster (BDC) through Control Hub. 

Use this script to quickly add and register a Data Collector and Transformer to your Control Hub organization, allowing you to easily experiment with building and testing SQL Server 2019 BDC pipelines and jobs.

The provisioned Data Collector is HTTPS-enabled and registered with the organization so you can use it as an authoring Data Collector. The provisioned Transformer is also HTTPS-enabled and registered with the organization. You can use the Transformer for both authoring and execution since Transformer submits Spark jobs that are executed in the SQL Server 2019 BDC cluster.

**Important:** This script is for development use only. Use the teardown script to remove all components created by this script.

## Prerequisites

To use the deployment script, you must have the following prerequisites:

- Control Hub organization and user account. 
- The Control Hub user account must have the Auth Token Administrator and Provisioning Operator roles.
- SQL Server 2019 Big Data Cluster.
- Kubernetes cluster.

## Running the Deployment Script


1. Open the streamsets-bdc-deployment-all-in-one.sh file.

2. Set the following variables:
   * SCH_URL: Control Hub URL
   * SCH_ORG: Control Hub organization
   * KUBE_NAMESPACE: Kubernetes namespace
   * CLUSTER_NAME: Kubernetes cluster name
   * RESOURCE_GROUP: Azure resource group
 
3. Run the script using the following command: 

   ```./streamsets-bdc-deployment-all-in-one.sh <ControlHub_username> <ControlHub_password>```

   For example: ./streamsets-bdc-deployment-all-in-one.sh user@myorg password

    - If asked to overwrite an object in the kubeconfig file, say yes: `y`.
    - If everything runs as expected, you should see the following message: `Deployment Successful`.

## Running the Teardown Script

The teardown script removes all components created by the deployment script. The script removes the Provisioning Agent, Transformer, and Data Collector from your Control Hub organization and Kubernetes cluster. 

Any Control Hub objects that you create, such as pipelines, jobs, and topologies, remain in your organization until you delete them.

1. Open streamsets-bdc-deployment-all-in-one-tear-down.sh file.

2. Set the following variables:
   * SCH_URL: Control Hub URL
   * SCH_ORG: Control Hub organization
   * KUBE_NAMESPACE: Kubernetes namespace
   * CLUSTER_NAME: Kubernetes cluster name
   * RESOURCE_GROUP: Azure resource group

3. Run the script using the following command:
   ```./streamsets-bdc-deployment-all-in-one-tear-down.sh <ControlHub_username> <ControlHub_password>```

   For example: ./streamsets-bdc-deployment-all-in-one-tear-down.sh user@myorg password

   - If asked to overwrite an object in the kubeconfig file, say yes: `y`.
   - If everything runs as expected, you should see the following message: `Successfully deleted all corresponding objects`.
