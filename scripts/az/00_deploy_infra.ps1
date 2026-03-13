param(
  [Parameter(Mandatory = $true)][string]$SubscriptionId,
  [Parameter(Mandatory = $true)][string]$ResourceGroup,
  [Parameter(Mandatory = $true)][string]$Location,
  [Parameter(Mandatory = $false)][ValidateSet("dev","prod")] [string]$Environment = "dev",
  [Parameter(Mandatory = $false)][string]$DeploymentName = "cqc-email-infra"
)

$ErrorActionPreference = "Stop"

az login | Out-Null
az account set --subscription $SubscriptionId

az group create `
  --name $ResourceGroup `
  --location $Location | Out-Null

$paramsFile = "infra/bicep/parameters/$Environment.bicepparam"

az deployment group create `
  --resource-group $ResourceGroup `
  --name $DeploymentName `
  --template-file "infra/bicep/main.bicep" `
  --parameters $paramsFile

Write-Host "Infrastructure deployment completed."
Write-Host "Deployment name: $DeploymentName"
