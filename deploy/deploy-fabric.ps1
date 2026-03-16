param(
    [string]$ConfigPath = "deploy/deploy.config.toml",
    [string]$FunctionPrincipalId = ""
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[deploy-fabric] $Message"
}

function Get-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }
    $json = python -c "import json, pathlib, tomllib; p=pathlib.Path(r'$Path'); print(json.dumps(tomllib.loads(p.read_text(encoding='utf-8'))))"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to parse config file: $Path"
    }
    return $json | ConvertFrom-Json
}

function Select-Value {
    param([string]$Configured, [string]$Default)
    if ([string]::IsNullOrWhiteSpace($Configured)) { return $Default }
    return $Configured
}

function Get-FabricToken {
    return az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv
}

function Invoke-FabricApi {
    param(
        [string]$Method,
        [string]$Uri,
        [object]$Body = $null
    )

    $token = Get-FabricToken
    $headers = @{ Authorization = "Bearer $token" }

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
    }

    $headers["Content-Type"] = "application/json"
    $jsonBody = $Body | ConvertTo-Json -Depth 50
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body $jsonBody
}

function Get-FabricItems {
    param([string]$WorkspaceId, [string]$Type = "")
    $base = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items"
    $uri = if ([string]::IsNullOrWhiteSpace($Type)) { $base } else { "$base?type=$Type" }
    $response = Invoke-FabricApi -Method "GET" -Uri $uri
    if ($response -and $response.value) { return @($response.value) }
    return @()
}

function Ensure-FabricFolder {
    param(
        [string]$WorkspaceId,
        [string]$DisplayName,
        [string]$ParentFolderId = ""
    )

    $foldersResponse = Invoke-FabricApi -Method "GET" -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/folders"
    $folders = if ($foldersResponse -and $foldersResponse.value) { @($foldersResponse.value) } else { @() }
    $existing = $folders | Where-Object {
        $_.displayName -eq $DisplayName -and (
            ([string]::IsNullOrWhiteSpace($ParentFolderId) -and [string]::IsNullOrWhiteSpace($_.parentFolderId)) -or
            ($_.parentFolderId -eq $ParentFolderId)
        )
    } | Select-Object -First 1
    if ($existing) {
        return $existing.id
    }

    $body = @{ displayName = $DisplayName }
    if (-not [string]::IsNullOrWhiteSpace($ParentFolderId)) {
        $body.parentFolderId = $ParentFolderId
    }
    $created = Invoke-FabricApi -Method "POST" -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/folders" -Body $body
    return $created.id
}

function Ensure-FabricNotebook {
    param(
        [string]$WorkspaceId,
        [string]$DisplayName,
        [string]$FolderId,
        [string]$SourceFilePath
    )

    if (-not (Test-Path $SourceFilePath)) {
        throw "Notebook source file not found: $SourceFilePath"
    }
    $source = Get-Content -Path $SourceFilePath -Raw -Encoding UTF8
    $payloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($source))
    $definition = @{
        format = "fabricGitSource"
        parts = @(
            @{
                path = "notebook-content.py"
                payload = $payloadBase64
                payloadType = "InlineBase64"
            }
        )
    }

    $existing = Get-FabricItems -WorkspaceId $WorkspaceId -Type "Notebook" | Where-Object {
        $_.displayName -eq $DisplayName
    } | Select-Object -First 1

    if (-not $existing) {
        $body = @{
            displayName = $DisplayName
            type = "Notebook"
            folderId = $FolderId
            definition = $definition
        }
        $created = Invoke-FabricApi -Method "POST" -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items" -Body $body
        return $created.id
    }

    $updateBody = @{ definition = $definition }
    Invoke-FabricApi -Method "POST" -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items/$($existing.id)/updateDefinition?updateMetadata=true" -Body $updateBody | Out-Null
    return $existing.id
}

function Ensure-FabricLakehouse {
    param(
        [string]$WorkspaceId,
        [string]$LakehouseId,
        [string]$LakehouseName,
        [string]$FolderId
    )

    if (-not [string]::IsNullOrWhiteSpace($LakehouseId)) {
        return $LakehouseId
    }

    $existing = Get-FabricItems -WorkspaceId $WorkspaceId -Type "Lakehouse" | Where-Object {
        $_.displayName -eq $LakehouseName
    } | Select-Object -First 1
    if ($existing) {
        return $existing.id
    }

    $body = @{
        displayName = $LakehouseName
        type = "Lakehouse"
    }
    if (-not [string]::IsNullOrWhiteSpace($FolderId)) {
        $body.folderId = $FolderId
    }
    $created = Invoke-FabricApi -Method "POST" -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items" -Body $body
    return $created.id
}

function Run-FabricNotebookAndWait {
    param(
        [string]$WorkspaceId,
        [string]$NotebookId,
        [object]$ExecutionData
    )

    $token = Get-FabricToken
    $headers = @{
        Authorization = "Bearer $token"
        "Content-Type" = "application/json"
    }
    $uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items/$NotebookId/jobs/instances?jobType=RunNotebook"
    $body = @{ executionData = $ExecutionData } | ConvertTo-Json -Depth 20

    $response = Invoke-WebRequest -Method POST -Uri $uri -Headers $headers -Body $body
    $location = $response.Headers["Location"]
    if ([string]::IsNullOrWhiteSpace($location)) {
        return
    }

    $deadline = (Get-Date).AddMinutes(20)
    do {
        Start-Sleep -Seconds 10
        $stateResponse = Invoke-RestMethod -Method GET -Uri $location -Headers @{ Authorization = "Bearer $(Get-FabricToken)" }
        $status = [string]($stateResponse.status)
        if ($status -in @("Succeeded", "Completed")) {
            return
        }
        if ($status -in @("Failed", "Cancelled")) {
            throw "Notebook bootstrap job ended with status '$status'."
        }
    } while ((Get-Date) -lt $deadline)

    throw "Notebook bootstrap job did not finish before timeout."
}

function Ensure-FabricRoleAssignment {
    param(
        [string]$WorkspaceId,
        [string]$PrincipalId,
        [string]$Role
    )
    if ([string]::IsNullOrWhiteSpace($PrincipalId)) {
        return
    }

    $assignments = Invoke-FabricApi -Method "GET" -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/roleAssignments"
    $existing = @()
    if ($assignments -and $assignments.value) { $existing = @($assignments.value) }
    $match = $existing | Where-Object {
        $_.principal.id -eq $PrincipalId -and $_.role -eq $Role
    } | Select-Object -First 1
    if ($match) {
        return
    }

    $body = @{
        principal = @{
            id = $PrincipalId
            type = "ServicePrincipal"
        }
        role = $Role
    }
    Invoke-FabricApi -Method "POST" -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/roleAssignments" -Body $body | Out-Null
}

$config = Get-Config -Path $ConfigPath
$workspaceId = $config.fabric.workspace_id
if ([string]::IsNullOrWhiteSpace($workspaceId)) {
    throw "fabric.workspace_id is required in deploy config."
}

$rootFolderName = Select-Value $config.fabric.root_folder_name "notebooks"
$mainFolderName = Select-Value $config.fabric.main_folder_name "main"
$modulesFolderName = Select-Value $config.fabric.modules_folder_name "modules"
$writerDisplayName = Select-Value $config.fabric.writer_notebook_display_name "cqc_silver_writer_main"
$bootstrapDisplayName = Select-Value $config.fabric.bootstrap_notebook_display_name "cqc_silver_bootstrap_main"
$lakehouseName = Select-Value $config.fabric.lakehouse_name "emailtrigger_lakehouse"
$lakehouseId = $config.fabric.lakehouse_id
$silverTableName = Select-Value $config.fabric.silver_table_name "dbo.cqc_email_silver"
$pushNotebooks = [bool]$config.fabric.push_notebooks
$runBootstrap = [bool]$config.fabric.run_bootstrap_table_notebook
$workspaceRole = Select-Value $config.fabric.workspace_role_for_function_mi "Contributor"

Write-Step "Ensuring Fabric folder tree."
$rootFolderId = Ensure-FabricFolder -WorkspaceId $workspaceId -DisplayName $rootFolderName
$mainFolderId = Ensure-FabricFolder -WorkspaceId $workspaceId -DisplayName $mainFolderName -ParentFolderId $rootFolderId
$modulesFolderId = Ensure-FabricFolder -WorkspaceId $workspaceId -DisplayName $modulesFolderName -ParentFolderId $rootFolderId

Write-Step "Ensuring Fabric lakehouse."
$lakehouseId = Ensure-FabricLakehouse `
    -WorkspaceId $workspaceId `
    -LakehouseId $lakehouseId `
    -LakehouseName $lakehouseName `
    -FolderId $rootFolderId

$writerNotebookId = ""
$bootstrapNotebookId = ""
if ($pushNotebooks) {
    Write-Step "Pushing Fabric notebook sources."
    $writerModulePath = $config.paths.writer_module_notebook_source
    $writerMainPath = $config.paths.writer_main_notebook_source
    $bootstrapModulePath = $config.paths.bootstrap_module_notebook_source
    $bootstrapMainPath = $config.paths.bootstrap_main_notebook_source

    Ensure-FabricNotebook -WorkspaceId $workspaceId -DisplayName "cqc_silver_module" -FolderId $modulesFolderId -SourceFilePath $writerModulePath | Out-Null
    Ensure-FabricNotebook -WorkspaceId $workspaceId -DisplayName "cqc_silver_bootstrap_module" -FolderId $modulesFolderId -SourceFilePath $bootstrapModulePath | Out-Null
    $writerNotebookId = Ensure-FabricNotebook -WorkspaceId $workspaceId -DisplayName $writerDisplayName -FolderId $mainFolderId -SourceFilePath $writerMainPath
    $bootstrapNotebookId = Ensure-FabricNotebook -WorkspaceId $workspaceId -DisplayName $bootstrapDisplayName -FolderId $mainFolderId -SourceFilePath $bootstrapMainPath
} else {
    $writerNotebook = Get-FabricItems -WorkspaceId $workspaceId -Type "Notebook" | Where-Object { $_.displayName -eq $writerDisplayName } | Select-Object -First 1
    if (-not $writerNotebook) {
        throw "Writer notebook '$writerDisplayName' was not found and push_notebooks=false."
    }
    $writerNotebookId = $writerNotebook.id
}

if ($runBootstrap -and -not [string]::IsNullOrWhiteSpace($bootstrapNotebookId)) {
    Write-Step "Running bootstrap notebook to ensure table exists."
    Run-FabricNotebookAndWait `
        -WorkspaceId $workspaceId `
        -NotebookId $bootstrapNotebookId `
        -ExecutionData @{
            parameters = @{
                table_name = @{
                    value = $silverTableName
                    type = "string"
                }
                lakehouse_id = @{
                    value = $lakehouseId
                    type = "string"
                }
            }
        }
}

if (-not [string]::IsNullOrWhiteSpace($FunctionPrincipalId)) {
    Write-Step "Ensuring Function MI Fabric workspace role assignment."
    Ensure-FabricRoleAssignment -WorkspaceId $workspaceId -PrincipalId $FunctionPrincipalId -Role $workspaceRole
}

$result = @{
    workspace_id = $workspaceId
    root_folder_id = $rootFolderId
    main_folder_id = $mainFolderId
    modules_folder_id = $modulesFolderId
    lakehouse_id = $lakehouseId
    writer_notebook_id = $writerNotebookId
    writer_notebook_job_endpoint = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items/$writerNotebookId/jobs/instances?jobType=RunNotebook"
}

Write-Output ($result | ConvertTo-Json -Compress)
