param(
    [string]$ConfigPath = "deploy/deploy.config.toml"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Write-Step {
    param([string]$Message)
    Write-Host "[deploy-function] $Message"
}

function Get-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Config file not found: $Path" }
    $json = python -c "import json, pathlib, tomllib; p=pathlib.Path(r'$Path'); print(json.dumps(tomllib.loads(p.read_text(encoding='utf-8'))))"
    if ($LASTEXITCODE -ne 0) { throw "Failed to parse config file: $Path" }
    return $json | ConvertFrom-Json
}

function Select-Value {
    param([string]$Configured, [string]$Default)
    if ([string]::IsNullOrWhiteSpace($Configured)) { return $Default }
    return $Configured
}

function Normalize-StorageAccountName {
    param([string]$Value)
    $normalized = ($Value.ToLower() -replace "[^a-z0-9]", "")
    if ([string]::IsNullOrWhiteSpace($normalized)) { throw "Invalid naming prefix for storage account." }
    if ($normalized.Length -lt 3) { $normalized = $normalized + "123" }
    if ($normalized.Length -gt 22) { $normalized = $normalized.Substring(0, 22) }
    return "st$normalized"
}

function Ensure-RoleAssignment {
    param(
        [string]$PrincipalId,
        [string]$Scope,
        [string]$Role,
        [string]$PrincipalType = "User"
    )
    $count = az role assignment list `
      --assignee-object-id $PrincipalId `
      --scope $Scope `
      --query "[?roleDefinitionName=='$Role'] | length(@)" `
      -o tsv
    if ($LASTEXITCODE -ne 0) { throw "Failed to query role assignments for '$Role'." }
    if ($count -eq "0") {
        Write-Step "Assigning role '$Role' on scope '$Scope'."
        az role assignment create `
          --assignee-object-id $PrincipalId `
          --assignee-principal-type $PrincipalType `
          --role $Role `
          --scope $Scope | Out-Null
    }
}

function Upload-BlobFromFile {
    param(
        [string]$StorageAccount,
        [string]$Container,
        [string]$BlobName,
        [string]$FilePath
    )
    if (-not (Test-Path $FilePath)) { throw "Prompt source file not found: $FilePath" }
    az storage blob upload `
      --auth-mode login `
      --account-name $StorageAccount `
      --container-name $Container `
      --name $BlobName `
      --file $FilePath `
      --overwrite true | Out-Null
}

if (-not (Get-Command func -ErrorAction SilentlyContinue)) {
    throw "Azure Functions Core Tools (func) is required."
}

$config = Get-Config -Path $ConfigPath
$subscriptionId = $config.azure.subscription_id
if ([string]::IsNullOrWhiteSpace($subscriptionId)) { $subscriptionId = az account show --query id -o tsv }
if ([string]::IsNullOrWhiteSpace($subscriptionId)) { throw "No Azure subscription id found. Set azure.subscription_id or run az login." }
az account set --subscription $subscriptionId

$prefix = $config.naming.prefix.ToLower()
$resourceGroup = Select-Value $config.azure.resource_group_name "rg-$prefix"
$functionAppName = Select-Value $config.naming.function_app_name "func-$prefix"
$storageAccountName = Select-Value $config.naming.storage_account_name (Normalize-StorageAccountName -Value $prefix)
$promptsContainer = Select-Value $config.storage.prompts_container_name "prompts"

if ([string]::IsNullOrWhiteSpace($config.naming.function_app_name)) {
    $detectedFunction = az functionapp list --resource-group $resourceGroup --query "[0].name" -o tsv 2>$null
    if (-not [string]::IsNullOrWhiteSpace($detectedFunction)) { $functionAppName = $detectedFunction }
}
if ([string]::IsNullOrWhiteSpace($config.naming.storage_account_name)) {
    $detectedStorage = az storage account list --resource-group $resourceGroup --query "[0].name" -o tsv 2>$null
    if (-not [string]::IsNullOrWhiteSpace($detectedStorage)) { $storageAccountName = $detectedStorage }
}

if ([string]::IsNullOrWhiteSpace($functionAppName)) { throw "Function app name could not be resolved." }
if ([string]::IsNullOrWhiteSpace($storageAccountName)) { throw "Storage account name could not be resolved." }

Write-Step "Publishing to $functionAppName ..."
func azure functionapp publish $functionAppName --python

Write-Step "Ensuring executor blob role for prompt seeding."
$executorObjectId = az ad signed-in-user show --query id -o tsv
$storageScope = az storage account show --resource-group $resourceGroup --name $storageAccountName --query id -o tsv
Ensure-RoleAssignment -PrincipalId $executorObjectId -Scope $storageScope -Role "Storage Blob Data Owner"

Write-Step "Seeding prompts container."
Upload-BlobFromFile -StorageAccount $storageAccountName -Container $promptsContainer -BlobName $config.prompts.validity_blob_name -FilePath $config.paths.validity_prompt_source
Upload-BlobFromFile -StorageAccount $storageAccountName -Container $promptsContainer -BlobName $config.prompts.extraction_blob_name -FilePath $config.paths.extraction_prompt_source

Write-Step "Syncing trigger metadata."
az rest --method post --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionAppName/syncfunctiontriggers?api-version=2025-05-01" | Out-Null

Write-Step "Function deployment complete."
