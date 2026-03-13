param(
  [Parameter(Mandatory = $true)][string]$ResourceGroup,
  [Parameter(Mandatory = $true)][string]$FunctionPrincipalId,
  [Parameter(Mandatory = $true)][string]$LogicAppPrincipalId,
  [Parameter(Mandatory = $true)][string]$ServiceBusNamespace,
  [Parameter(Mandatory = $true)][string]$QueueName,
  [Parameter(Mandatory = $true)][string]$FabricWriteQueueName,
  [Parameter(Mandatory = $false)][string]$AoaiResourceId = "",
  [Parameter(Mandatory = $false)][string]$DocIntelResourceId = "",
  [Parameter(Mandatory = $false)][string]$AoaiRoleDefinitionId = "",
  [Parameter(Mandatory = $false)][string]$DocIntelRoleDefinitionId = ""
)

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
