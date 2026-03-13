param(
  [Parameter(Mandatory = $true)][string]$ResourceGroup,
  [Parameter(Mandatory = $true)][string]$FunctionAppName,
  [Parameter(Mandatory = $true)][string]$ServiceBusQueueName,
  [Parameter(Mandatory = $true)][string]$AoaiEndpoint,
  [Parameter(Mandatory = $true)][string]$DocIntelEndpoint,
  [Parameter(Mandatory = $true)][string]$FabricNotebookJobEndpoint,
  [Parameter(Mandatory = $true)][string]$FabricWorkspaceId,
  [Parameter(Mandatory = $true)][string]$FabricLakehouseId,
  [Parameter(Mandatory = $true)][string]$FabricSilverTable,
  [Parameter(Mandatory = $true)][string]$MissingInfoLogicAppUrl
)

az functionapp config appsettings set `
  --resource-group $ResourceGroup `
  --name $FunctionAppName `
  --settings `
    "SERVICEBUS_QUEUE_NAME=$ServiceBusQueueName" `
    "ACTIVE_MODEL_PROFILE=default" `
    "ACTIVE_EXTRACTION_SCHEMA=coa_v1" `
    "CONFIDENCE_THRESHOLD_REQUIRED=0.97" `
    "AOAI_ENDPOINT=$AoaiEndpoint" `
    "AOAI_API_VERSION=2024-06-01" `
    "DOCINTEL_ENDPOINT=$DocIntelEndpoint" `
    "FABRIC_NOTEBOOK_JOB_ENDPOINT=$FabricNotebookJobEndpoint" `
    "FABRIC_WORKSPACE_ID=$FabricWorkspaceId" `
    "FABRIC_LAKEHOUSE_ID=$FabricLakehouseId" `
    "FABRIC_SILVER_TABLE=$FabricSilverTable" `
    "MISSING_INFO_LOGICAPP_URL=$MissingInfoLogicAppUrl"
