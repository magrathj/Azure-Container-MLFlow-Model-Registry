RG_NAME=mlflowserver-aci             # Resource Group name
ACR_NAME=mlflowservermodelrepo       # Azure Container Registry registry name
AKV_NAME=keyvaultmlflowserver        # Azure Key Vault vault name
RG_LOCATION=northeurope              # Resource Group location
ACI_IMAGE_NAME=mlflowserver:1.3
ACI_CONTAINER_NAME=mlflowserver
ACI_DNS_LABEL=aci-mlflow-dns
ACI_STORAGE_ACCOUNT_NAME=storage$RANDOM
ACI_STORAGE_CONTAINER_NAME=acicontainer
ACI_SHARE_MNT_PATH=/mnt/azfiles
ACI_SHARE_NAME=acishare

MLFLOW_SERVER_FILE_STORE=$ACI_SHARE_MNT_PATH/mlruns
MLFLOW_SERVER_DEFAULT_ARTIFACT_ROOT=wasbs://$ACI_STORAGE_CONTAINER_NAME@$ACI_STORAGE_ACCOUNT_NAME.blob.core.windows.net/mlartefacts
MLFLOW_SERVER_HOST=0.0.0.0
MLFLOW_SERVER_PORT=5000


echo "Creating resource group: $RG_NAME"
az group create --name "$RG_NAME" --location "$RG_LOCATION"

echo "Creating key vault: $AKV_NAME"
az keyvault create -g $RG_NAME -n $AKV_NAME

echo "Creating Azure Container Registry: $ACR_NAME"
az acr create --resource-group $RG_NAME --name $ACR_NAME --sku Basic

# Create service principal, store its password in vault (the registry *password*)
az keyvault secret set \
  --vault-name $AKV_NAME \
  --name $ACR_NAME-pull-pwd \
  --value $(az ad sp create-for-rbac \
                --name http://$ACR_NAME-pull \
                --scopes $(az acr show --name $ACR_NAME --query id --output tsv) \
                --role acrpull \
                --query password \
                --output tsv)

# Store service principal ID in vault (the registry *username*)
az keyvault secret set \
    --vault-name $AKV_NAME \
    --name $ACR_NAME-pull-usr \
    --value $(az ad sp show --id http://$ACR_NAME-pull --query appId --output tsv)

ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RG_NAME --query "loginServer" --output tsv)
echo "ACR Login Server: $ACR_LOGIN_SERVER"


# Login to ACR
az acr login --name $ACR_NAME

docker build --tag mlflowserver:1.4 . 

docker tag mlflowserver:1.4 mlflowserver.azurecr.io/mlflowserver:1.4

docker push mlflowservermodelrepo.azurecr.io/mlflowserver

ACI_IMAGE=$ACR_LOGIN_SERVER/$ACI_IMAGE_NAME
echo "ACI IMAGE: $ACI_IMAGE"


#################
# DEPLOY

echo "Creating storage account: $ACI_STORAGE_ACCOUNT_NAME"
az storage account create \
    --resource-group $RG_NAME \
    --location $RG_LOCATION \
    --name $ACI_STORAGE_ACCOUNT_NAME \
    --sku Standard_LRS

# Export the connection string as an environment variable. The following 'az storage share create' command
# references this environment variable when creating the Azure file share.
echo "Exporting storage connection string: $ACI_STORAGE_ACCOUNT_NAME"
export AZURE_STORAGE_CONNECTION_STRING=`az storage account show-connection-string --resource-group $RG_NAME --name $ACI_STORAGE_ACCOUNT_NAME --output tsv`

# Mlflow requires environment variable (AZURE_STORAGE_ACCESS_KEY) to be set at client and with Server
# Export the access keyas an environment variable
echo "Exporting storage keys: $ACI_STORAGE_ACCOUNT_NAME"
export AZURE_STORAGE_ACCESS_KEY=$(az storage account keys list --resource-group $RG_NAME --account-name $ACI_STORAGE_ACCOUNT_NAME --query "[0].value" --output tsv)

echo "Creating the file share for MLFlow FileStore: $ACI_SHARE_NAME"
az storage share create -n $ACI_SHARE_NAME

echo "Creating blob container for MLFlow artefacts: $ACI_STORAGE_CONTAINER_NAME"
az storage container create -n $ACI_STORAGE_CONTAINER_NAME

echo "Deploying container: $ACI_CONTAINER_NAME"
az container create \
    --resource-group $RG_NAME \
    --name $ACI_CONTAINER_NAME \
    --image $ACI_IMAGE \
    --dns-name-label $ACI_DNS_LABEL \
    --ports $MLFLOW_SERVER_PORT \
    --registry-login-server $ACR_LOGIN_SERVER \
    --registry-username $(az keyvault secret show --vault-name $AKV_NAME -n $ACR_NAME-pull-usr --query value -o tsv) \
    --registry-password $(az keyvault secret show --vault-name $AKV_NAME -n $ACR_NAME-pull-pwd --query value -o tsv) \ 
    --azure-file-volume-account-name $ACI_STORAGE_ACCOUNT_NAME \
    --azure-file-volume-account-key $AZURE_STORAGE_ACCESS_KEY \
    --azure-file-volume-share-name $ACI_SHARE_NAME \
    --azure-file-volume-mount-path $ACI_SHARE_MNT_PATH \
    --environment-variables AZURE_STORAGE_ACCESS_KEY=$AZURE_STORAGE_ACCESS_KEY \
        MLFLOW_SERVER_FILE_STORE=$MLFLOW_SERVER_FILE_STORE \
        MLFLOW_SERVER_DEFAULT_ARTIFACT_ROOT=$MLFLOW_SERVER_DEFAULT_ARTIFACT_ROOT \
        MLFLOW_SERVER_HOST=$MLFLOW_SERVER_HOST

echo "Completed deployment."

echo "get container ip address"
az container show --name $ACI_CONTAINER_NAME --resource-group $RG_NAME --output table
