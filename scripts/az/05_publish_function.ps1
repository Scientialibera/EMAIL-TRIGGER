param(
  [Parameter(Mandatory = $true)][string]$ResourceGroup,
  [Parameter(Mandatory = $false)][string]$FunctionAppName = "",
  [Parameter(Mandatory = $false)][string]$DeploymentName = "cqc-email-infra"
)

$ErrorActionPreference = "Stop"

if (-not $FunctionAppName) {
  $FunctionAppName = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query properties.outputs.functionAppName.value `
    -o tsv
}

func azure functionapp publish $FunctionAppName --python

Write-Host "Function app publish completed for $FunctionAppName."
