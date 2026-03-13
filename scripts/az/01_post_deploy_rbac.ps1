param(
  [Parameter(Mandatory = $true)][string]$ResourceGroup,
  [Parameter(Mandatory = $false)][string]$FunctionPrincipalId = "",
  [Parameter(Mandatory = $false)][string]$LogicAppPrincipalId = "",
  [Parameter(Mandatory = $false)][string]$ServiceBusNamespace = "",
  [Parameter(Mandatory = $false)][string]$QueueName = "",
  [Parameter(Mandatory = $false)][string]$FabricWriteQueueName = "",
  [Parameter(Mandatory = $false)][string]$DeploymentName = "cqc-email-infra",
  [Parameter(Mandatory = $false)][string]$AoaiResourceId = "",
  [Parameter(Mandatory = $false)][string]$DocIntelResourceId = "",
  [Parameter(Mandatory = $false)][string]$AoaiRoleDefinitionId = "",
  [Parameter(Mandatory = $false)][string]$DocIntelRoleDefinitionId = ""
)

$ErrorActionPreference = "Stop"

if (-not $FunctionPrincipalId -or -not $LogicAppPrincipalId -or -not $QueueName -or -not $FabricWriteQueueName -or -not $ServiceBusNamespace) {
  $outputs = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query properties.outputs `
    -o json | ConvertFrom-Json

  if (-not $FunctionPrincipalId) { $FunctionPrincipalId = $outputs.functionPrincipalId.value }
  if (-not $LogicAppPrincipalId) { $LogicAppPrincipalId = $outputs.logicAppPrincipalId.value }
  if (-not $QueueName) { $QueueName = $outputs.serviceBusQueueName.value }
  if (-not $FabricWriteQueueName) { $FabricWriteQueueName = $outputs.fabricWriteQueueName.value }
  if (-not $ServiceBusNamespace) { $ServiceBusNamespace = $outputs.serviceBusNamespaceName.value }
}

$queueScope = "/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$ResourceGroup/providers/Microsoft.ServiceBus/namespaces/$ServiceBusNamespace/queues/$QueueName"
$fabricWriteQueueScope = "/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$ResourceGroup/providers/Microsoft.ServiceBus/namespaces/$ServiceBusNamespace/queues/$FabricWriteQueueName"

# Logic App -> Service Bus sender
az role assignment create `
  --assignee-object-id $LogicAppPrincipalId `
  --assignee-principal-type ServicePrincipal `
  --role "Azure Service Bus Data Sender" `
  --scope $queueScope

# Function -> Service Bus receiver
az role assignment create `
  --assignee-object-id $FunctionPrincipalId `
  --assignee-principal-type ServicePrincipal `
  --role "Azure Service Bus Data Receiver" `
  --scope $queueScope

# Function -> Fabric write command queue sender/receiver
az role assignment create `
  --assignee-object-id $FunctionPrincipalId `
  --assignee-principal-type ServicePrincipal `
  --role "Azure Service Bus Data Sender" `
  --scope $fabricWriteQueueScope

az role assignment create `
  --assignee-object-id $FunctionPrincipalId `
  --assignee-principal-type ServicePrincipal `
  --role "Azure Service Bus Data Receiver" `
  --scope $fabricWriteQueueScope

if ($AoaiResourceId -and $AoaiRoleDefinitionId) {
  az role assignment create `
    --assignee-object-id $FunctionPrincipalId `
    --assignee-principal-type ServicePrincipal `
    --role $AoaiRoleDefinitionId `
    --scope $AoaiResourceId
}

if ($DocIntelResourceId -and $DocIntelRoleDefinitionId) {
  az role assignment create `
    --assignee-object-id $FunctionPrincipalId `
    --assignee-principal-type ServicePrincipal `
    --role $DocIntelRoleDefinitionId `
    --scope $DocIntelResourceId
}
