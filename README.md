# StreamSets SQL Server BDC Deployment Script

The StreamSets SQL Server BDC deployment script enables you to seamlessly spin up Data Collector and Transformer instances, registered to Control Hub.

The script auto-creates the following for you:

1. A namespace called ‘streamsets’ in your Kubernetes cluster (adjacent to your BDC cluster) where all components described below will be created.
2. A provisioning agent to automatically provision Data Collector containers in the Kubernetes cluster. The agent reports to StreamSets Control Hub and executes commands on its behalf in the Kubernetes cluster.
3. A Traefik ingress controller is used to route external traffic into the Data Collector & Transformer service and provide TLS termination. The SSL configuration creates and configures self-signed certificates.
4. A Data Collector instance with access to the UI via a public HTTPS URL. This is created via a Kubernetes deployment of replica 1, a service for the deployment and an ingress. You can use Data Collector for both authoring and execution of data flows for ingesting data to and from SQL Server 2019 Big Data Clusters.
5. A Transformer instance with access to the UI via a public HTTPS URL. This is created via a Kubernetes deployment of replica 1, a service for the deployment and an ingress. You can use Transformer for both authoring and execution of data flows that run on Spark. Transformer submits Spark jobs that are executed in the SQL Server 2019 BDC cluster.
6. Before you can use Data Collector and Transformer instances for designing, validating and running pipelines from Control Hub, you must click on the Data Collector and Transformer's https urls individually from Control Hub and accept the self-signed certificate on your browser.

Use this script to quickly add and register a Data Collector and Transformer to your Control Hub organization, allowing you to easily experiment with building and testing SQL Server 2019 BDC pipelines and jobs.

<b> **Important:** This script is for development use only. Use this script to quickly add and register a Data Collector and Transformer to your Control Hub organization, allowing you to easily experiment with building and testing SQL Server 2019 BDC pipelines and jobs. Use the teardown script to remove all components created by this script.
Follow the security guidelines set by your organization for production ready deployments. </b>

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

   For example: `./streamsets-bdc-deployment-all-in-one.sh user@myorg password`

    - If asked to overwrite an object in the kubeconfig file, say yes: `y`
    - If everything runs as expected, you should see the following message: "Deployment Successful"

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

   For example: `./streamsets-bdc-deployment-all-in-one-tear-down.sh user@myorg password`

   - If asked to overwrite an object in the kubeconfig file, say yes: `y`
   - If everything runs as expected, you should see the following message: "Successfully deleted all corresponding objects"
