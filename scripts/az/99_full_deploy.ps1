param(
  [Parameter(Mandatory = $true)][string]$SubscriptionId,
  [Parameter(Mandatory = $true)][string]$ResourceGroup,
  [Parameter(Mandatory = $true)][string]$Location,
  [Parameter(Mandatory = $false)][ValidateSet("dev","prod")] [string]$Environment = "dev",
  [Parameter(Mandatory = $false)][string]$DeploymentName = "cqc-email-infra",
  [Parameter(Mandatory = $true)][string]$FabricWorkspaceId,
  [Parameter(Mandatory = $true)][string]$ServiceBusConnectionResourceId,
  [Parameter(Mandatory = $true)][string]$OfficeConnectionResourceId,
  [Parameter(Mandatory = $true)][string]$ServiceBusNamespaceFqdn,
  [Parameter(Mandatory = $true)][string]$AoaiEndpoint,
  [Parameter(Mandatory = $true)][string]$DocIntelEndpoint,
  [Parameter(Mandatory = $true)][string]$FabricNotebookJobEndpoint,
  [Parameter(Mandatory = $true)][string]$FabricLakehouseId,
  [Parameter(Mandatory = $true)][string]$FabricSilverTable,
  [Parameter(Mandatory = $true)][string]$MissingInfoLogicAppUrl,
  [Parameter(Mandatory = $true)][string]$RejectionNoticeLogicAppUrl
)

$ErrorActionPreference = "Stop"

& "scripts/az/00_deploy_infra.ps1" `
  -SubscriptionId $SubscriptionId `
  -ResourceGroup $ResourceGroup `
  -Location $Location `
  -Environment $Environment `
  -DeploymentName $DeploymentName

& "scripts/az/01_post_deploy_rbac.ps1" `
  -ResourceGroup $ResourceGroup `
  -DeploymentName $DeploymentName

$functionPrincipalId = az deployment group show --resource-group $ResourceGroup --name $DeploymentName --query properties.outputs.functionPrincipalId.value -o tsv
$logicAppName = az deployment group show --resource-group $ResourceGroup --name $DeploymentName --query properties.outputs.logicAppName.value -o tsv
$serviceBusQueueName = az deployment group show --resource-group $ResourceGroup --name $DeploymentName --query properties.outputs.serviceBusQueueName.value -o tsv
$fabricWriteQueueName = az deployment group show --resource-group $ResourceGroup --name $DeploymentName --query properties.outputs.fabricWriteQueueName.value -o tsv
$functionAppName = az deployment group show --resource-group $ResourceGroup --name $DeploymentName --query properties.outputs.functionAppName.value -o tsv

& "scripts/az/02_add_function_mi_to_fabric.ps1" `
  -FunctionPrincipalId $functionPrincipalId `
  -FabricWorkspaceId $FabricWorkspaceId

& "scripts/az/03_configure_logicapp_connections.ps1" `
  -ResourceGroup $ResourceGroup `
  -LogicAppName $logicAppName `
  -ServiceBusConnectionResourceId $ServiceBusConnectionResourceId `
  -OfficeConnectionResourceId $OfficeConnectionResourceId

& "scripts/az/04_seed_app_settings.ps1" `
  -ResourceGroup $ResourceGroup `
  -FunctionAppName $functionAppName `
  -ServiceBusNamespaceFqdn $ServiceBusNamespaceFqdn `
  -ServiceBusQueueName $serviceBusQueueName `
  -FabricWriteQueueName $fabricWriteQueueName `
  -AoaiEndpoint $AoaiEndpoint `
  -DocIntelEndpoint $DocIntelEndpoint `
  -FabricNotebookJobEndpoint $FabricNotebookJobEndpoint `
  -FabricWorkspaceId $FabricWorkspaceId `
  -FabricLakehouseId $FabricLakehouseId `
  -FabricSilverTable $FabricSilverTable `
  -MissingInfoLogicAppUrl $MissingInfoLogicAppUrl `
  -RejectionNoticeLogicAppUrl $RejectionNoticeLogicAppUrl

& "scripts/az/05_publish_function.ps1" `
  -ResourceGroup $ResourceGroup `
  -FunctionAppName $functionAppName `
  -DeploymentName $DeploymentName

Write-Host "Full deployment flow completed."
