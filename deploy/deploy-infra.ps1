param(
    [string]$ConfigPath = "deploy/deploy.config.toml"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Write-Step {
    param([string]$Message)
    Write-Host "[deploy-infra] $Message"
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

function Normalize-ServiceBusNamespaceName {
    param([string]$Value)
    $normalized = ($Value.ToLower() -replace "[^a-z0-9-]", "-")
    $normalized = ($normalized -replace "^-+", "") -replace "-+$", ""
    if ([string]::IsNullOrWhiteSpace($normalized)) { throw "Invalid naming prefix for service bus namespace." }
    if ($normalized.Length -gt 38) { $normalized = $normalized.Substring(0, 38) }
    return "sbns-$normalized"
}

function Ensure-RoleAssignment {
    param(
        [string]$PrincipalId,
        [string]$Scope,
        [string]$Role,
        [string]$PrincipalType = "ServicePrincipal"
    )
    $count = az role assignment list `
      --assignee-object-id $PrincipalId `
      --scope $Scope `
      --query "[?roleDefinitionName=='$Role'] | length(@)" `
      -o tsv
    if ($LASTEXITCODE -ne 0) { throw "Failed to query role assignments for role '$Role'." }
    if ($count -eq "0") {
        Write-Step "Assigning role '$Role' on scope '$Scope'."
        az role assignment create `
          --assignee-object-id $PrincipalId `
          --assignee-principal-type $PrincipalType `
          --role $Role `
          --scope $Scope | Out-Null
    } else {
        Write-Step "Role '$Role' already assigned."
    }
}

$config = Get-Config -Path $ConfigPath

$subscriptionId = $config.azure.subscription_id
if ([string]::IsNullOrWhiteSpace($subscriptionId)) { $subscriptionId = az account show --query id -o tsv }
if ([string]::IsNullOrWhiteSpace($subscriptionId)) { throw "No Azure subscription id found. Set azure.subscription_id or run az login." }

$prefix = $config.naming.prefix.ToLower()
$location = Select-Value $config.azure.location "eastus2"
$resourceGroup = Select-Value $config.azure.resource_group_name "rg-$prefix"
$functionAppName = Select-Value $config.naming.function_app_name "func-$prefix"
$storageAccountName = Select-Value $config.naming.storage_account_name (Normalize-StorageAccountName -Value $prefix)
$serviceBusNamespace = Select-Value $config.naming.servicebus_namespace_name (Normalize-ServiceBusNamespaceName -Value $prefix)
$processQueue = $config.queues.process_queue_name
$fabricWriteQueue = $config.queues.fabric_write_queue_name
$promptsContainer = Select-Value $config.storage.prompts_container_name "prompts"

$aoaiResourceId = $config.dependencies.aoai_resource_id
$docIntelResourceId = $config.dependencies.docintel_resource_id
$aoaiEndpoint = $config.dependencies.aoai_endpoint
$docIntelEndpoint = $config.dependencies.docintel_endpoint

$missingInfoUrl = $config.logic_app.missing_info_logicapp_url
$rejectionUrl = $config.logic_app.rejection_notice_logicapp_url
$targetSharedMailbox = $config.mailbox.target_shared_mailbox
$missingInfoSenderMailbox = $config.mailbox.missing_info_sender_mailbox
$rejectionSenderMailbox = $config.mailbox.rejection_sender_mailbox
$logicAppConnectorIdentityUpn = $config.mailbox.logic_app_connector_identity_upn

if ([string]::IsNullOrWhiteSpace($aoaiEndpoint) -or [string]::IsNullOrWhiteSpace($docIntelEndpoint)) {
    throw "dependencies.aoai_endpoint and dependencies.docintel_endpoint are required."
}
if ([string]::IsNullOrWhiteSpace($missingInfoUrl) -or [string]::IsNullOrWhiteSpace($rejectionUrl)) {
    throw "logic_app.missing_info_logicapp_url and logic_app.rejection_notice_logicapp_url are required."
}
if ([string]::IsNullOrWhiteSpace($targetSharedMailbox) -or
    [string]::IsNullOrWhiteSpace($missingInfoSenderMailbox) -or
    [string]::IsNullOrWhiteSpace($rejectionSenderMailbox) -or
    [string]::IsNullOrWhiteSpace($logicAppConnectorIdentityUpn)) {
    throw "mailbox.target_shared_mailbox, mailbox.missing_info_sender_mailbox, mailbox.rejection_sender_mailbox, and mailbox.logic_app_connector_identity_upn are required."
}
if ([string]::IsNullOrWhiteSpace($config.fabric.workspace_id)) {
    throw "fabric.workspace_id is required."
}

Write-Step "Using subscription: $subscriptionId"
az account set --subscription $subscriptionId

Write-Step "Ensuring resource group '$resourceGroup'."
$rgExists = az group exists --name $resourceGroup -o tsv
if ($rgExists -ne "true") { az group create --name $resourceGroup --location $location | Out-Null }
$resourceGroupScope = az group show --name $resourceGroup --query id -o tsv

$executorObjectId = az ad signed-in-user show --query id -o tsv
if ([string]::IsNullOrWhiteSpace($executorObjectId)) { throw "Could not resolve signed-in user object id." }
Ensure-RoleAssignment -PrincipalId $executorObjectId -PrincipalType User -Scope $resourceGroupScope -Role "Contributor"

Write-Step "Ensuring storage account '$storageAccountName'."
$storageExists = az storage account list --resource-group $resourceGroup --query "[?name=='$storageAccountName'] | length(@)" -o tsv
if ($storageExists -eq "0") {
    az storage account create `
      --resource-group $resourceGroup `
      --name $storageAccountName `
      --location $location `
      --sku Standard_LRS `
      --kind StorageV2 `
      --min-tls-version TLS1_2 `
      --allow-blob-public-access false | Out-Null
}
$storageScope = az storage account show --resource-group $resourceGroup --name $storageAccountName --query id -o tsv
Ensure-RoleAssignment -PrincipalId $executorObjectId -PrincipalType User -Scope $storageScope -Role "Storage Blob Data Owner"

Write-Step "Ensuring prompts container '$promptsContainer'."
$containerExists = az storage container exists --account-name $storageAccountName --name $promptsContainer --auth-mode login --query exists -o tsv
if ($containerExists -ne "true") {
    az storage container create --account-name $storageAccountName --name $promptsContainer --auth-mode login | Out-Null
}

Write-Step "Ensuring Service Bus namespace '$serviceBusNamespace'."
$sbExists = az servicebus namespace list --resource-group $resourceGroup --query "[?name=='$serviceBusNamespace'] | length(@)" -o tsv
if ($sbExists -eq "0") {
    az servicebus namespace create `
      --resource-group $resourceGroup `
      --name $serviceBusNamespace `
      --location $location `
      --sku Standard | Out-Null
}

Write-Step "Ensuring Service Bus queue '$processQueue'."
$processQueueExists = az servicebus queue list --resource-group $resourceGroup --namespace-name $serviceBusNamespace --query "[?name=='$processQueue'] | length(@)" -o tsv
if ($processQueueExists -eq "0") {
    az servicebus queue create `
      --resource-group $resourceGroup `
      --namespace-name $serviceBusNamespace `
      --name $processQueue `
      --enable-session false | Out-Null
}

Write-Step "Ensuring Service Bus queue '$fabricWriteQueue' with sessions."
$writeQueueExists = az servicebus queue list --resource-group $resourceGroup --namespace-name $serviceBusNamespace --query "[?name=='$fabricWriteQueue'] | length(@)" -o tsv
if ($writeQueueExists -eq "0") {
    az servicebus queue create `
      --resource-group $resourceGroup `
      --namespace-name $serviceBusNamespace `
      --name $fabricWriteQueue `
      --enable-session true | Out-Null
}

Write-Step "Ensuring Function App '$functionAppName' on Flex Consumption."
$funcExists = az functionapp list --resource-group $resourceGroup --query "[?name=='$functionAppName'] | length(@)" -o tsv
if ($funcExists -eq "0") {
    az functionapp create `
      --resource-group $resourceGroup `
      --name $functionAppName `
      --storage-account $storageAccountName `
      --flexconsumption-location $location `
      --runtime python `
      --runtime-version 3.11 `
      --functions-version 4 | Out-Null
}

az functionapp identity assign --resource-group $resourceGroup --name $functionAppName --identities [system] | Out-Null
$functionPrincipalId = az functionapp identity show --resource-group $resourceGroup --name $functionAppName --query principalId -o tsv
if ([string]::IsNullOrWhiteSpace($functionPrincipalId)) { throw "Could not resolve function managed identity principal id." }

$processQueueScope = az servicebus queue show --resource-group $resourceGroup --namespace-name $serviceBusNamespace --name $processQueue --query id -o tsv
$writeQueueScope = az servicebus queue show --resource-group $resourceGroup --namespace-name $serviceBusNamespace --name $fabricWriteQueue --query id -o tsv

Write-Step "Ensuring function MI Service Bus RBAC."
Ensure-RoleAssignment -PrincipalId $functionPrincipalId -Scope $processQueueScope -Role "Azure Service Bus Data Receiver"
Ensure-RoleAssignment -PrincipalId $functionPrincipalId -Scope $writeQueueScope -Role "Azure Service Bus Data Receiver"
Ensure-RoleAssignment -PrincipalId $functionPrincipalId -Scope $writeQueueScope -Role "Azure Service Bus Data Sender"

Write-Step "Ensuring function MI blob data-plane access."
Ensure-RoleAssignment -PrincipalId $functionPrincipalId -Scope $storageScope -Role "Storage Blob Data Reader"

Write-Step "Bootstrapping Fabric artifacts."
$fabricResultRaw = powershell -ExecutionPolicy Bypass -File "deploy/deploy-fabric.ps1" -ConfigPath $ConfigPath -FunctionPrincipalId $functionPrincipalId
$fabricResultJson = $fabricResultRaw | Select-Object -Last 1
$fabricResult = $fabricResultJson | ConvertFrom-Json

if (-not [string]::IsNullOrWhiteSpace($aoaiResourceId)) {
    $aoaiRole = Select-Value $config.dependencies.aoai_invoke_role_definition_id "Cognitive Services OpenAI User"
    Ensure-RoleAssignment -PrincipalId $functionPrincipalId -Scope $aoaiResourceId -Role $aoaiRole
}
if (-not [string]::IsNullOrWhiteSpace($docIntelResourceId)) {
    $docRole = Select-Value $config.dependencies.docintel_invoke_role_definition_id "Cognitive Services User"
    Ensure-RoleAssignment -PrincipalId $functionPrincipalId -Scope $docIntelResourceId -Role $docRole
}

$sbFqdn = "$serviceBusNamespace.servicebus.windows.net"
$appSettings = @(
    "SERVICEBUS_NAMESPACE_FQDN=$sbFqdn",
    "SERVICEBUS_QUEUE_NAME=$processQueue",
    "FABRIC_WRITE_QUEUE_NAME=$fabricWriteQueue",
    "SERVICEBUS_CONNECTION__fullyQualifiedNamespace=$sbFqdn",
    "ACTIVE_MODEL_PROFILE=$($config.app_settings.active_model_profile)",
    "ACTIVE_EXTRACTION_SCHEMA=$($config.app_settings.active_extraction_schema)",
    "CONFIDENCE_THRESHOLD_REQUIRED=$($config.app_settings.confidence_threshold_required)",
    "AOAI_ENDPOINT=$aoaiEndpoint",
    "AOAI_API_VERSION=$($config.app_settings.aoai_api_version)",
    "DOCINTEL_ENDPOINT=$docIntelEndpoint",
    "STORAGE_ACCOUNT_NAME=$storageAccountName",
    "PROMPTS_CONTAINER_NAME=$promptsContainer",
    "VALIDITY_PROMPT_BLOB_NAME=$($config.prompts.validity_blob_name)",
    "EXTRACTION_PROMPT_BLOB_NAME=$($config.prompts.extraction_blob_name)",
    "FABRIC_NOTEBOOK_JOB_ENDPOINT=$($fabricResult.writer_notebook_job_endpoint)",
    "FABRIC_WORKSPACE_ID=$($fabricResult.workspace_id)",
    "FABRIC_LAKEHOUSE_ID=$($fabricResult.lakehouse_id)",
    "FABRIC_SILVER_TABLE=$($config.fabric.silver_table_name)",
    "FABRIC_NOTEBOOK_POLL_SECONDS=$($config.app_settings.fabric_notebook_poll_seconds)",
    "FABRIC_NOTEBOOK_WAIT_TIMEOUT_SECONDS=$($config.app_settings.fabric_notebook_wait_timeout_seconds)",
    "MISSING_INFO_LOGICAPP_URL=$missingInfoUrl",
    "REJECTION_NOTICE_LOGICAPP_URL=$rejectionUrl",
    "TARGET_SHARED_MAILBOX=$targetSharedMailbox",
    "MISSING_INFO_SENDER_MAILBOX=$missingInfoSenderMailbox",
    "REJECTION_SENDER_MAILBOX=$rejectionSenderMailbox",
    "LOGIC_APP_CONNECTOR_IDENTITY_UPN=$logicAppConnectorIdentityUpn"
)

Write-Step "Applying function app settings."
az functionapp config appsettings set --resource-group $resourceGroup --name $functionAppName --settings $appSettings | Out-Null

Write-Step "Infrastructure deployment complete."
Write-Output ""
Write-Output "Resource group: $resourceGroup"
Write-Output "Storage account: $storageAccountName"
Write-Output "Service Bus namespace: $serviceBusNamespace"
Write-Output "Function app: $functionAppName"
Write-Output "Fabric notebook endpoint: $($fabricResult.writer_notebook_job_endpoint)"
Write-Output "Shared mailbox (assumed existing): $targetSharedMailbox"
Write-Output "IMPORTANT: Exchange Online mailbox permissions must be granted to '$logicAppConnectorIdentityUpn' (FullAccess on shared mailbox + SendAs on sender mailboxes)."
