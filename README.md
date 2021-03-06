# MLFlow Model Repository Server on Azure Container Registry
This repository provides necessary artefacts to quicky and easily deploy an [MLflow Tracking server](https://mlflow.org/docs/latest/tracking.html) on Azure. 

[MLflow](https://mlflow.org/docs/latest/index.html) is an open source platform for managing the end-to-end machine learning lifecycle.

## Deploy

### Requirements: 
- [az cli 2.0+](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

### Deployment
1. Ensure you are logged-in in the azure cli. 
   - Run `az login` to login.
   - Run `az account set -s <SUBSCRIPTION_ID>` to set target azure subscription.
2. Ensure you are in the `deploy-aci` folder.
3. Open `deploy-aci.sh` and inspect/change top parameters, if necessary.
4. Run `./deploy-aci.sh`
5. Validate deployment by navigating to the ACI IP:port (default: 5000). NOTE, that it takes a few moments for the server to startup.
   - You can retrieve IP and port of the deployed Tracking Server on ACI by running: 
   - `az container show --name <ACI_NAME> --resource-group <ACI_RESOURCE_GROUP> --output table`

![ACI Deployment](./images/mlflow-aci-deployment.PNG)

## Logging Data to MLFlow Tracking Server


# Documentation for MLFlow Model Repository 
Documentaion for mlflow repository and scripts

### Current functionality 
* Mlflow server deployed on a container instance with:
    * storage container - with blob and file store
    * docker image for mlflow server
* Version 1.8.0 of mlflow 
* Models saved to blob storage and meta data saved to SQLlite db inside the container


###  Build Docker Image

Build image

```
docker build --tag jaredmagrath/mlflowserver-azure:1.8.2 .\mlflow-tracking-docker\
```

Push to dockerhub

```
docker push jaredmagrath/mlflowserver-azure:1.8.2
```
