param(
  [Parameter(Mandatory = $true)][string]$FunctionPrincipalId,
  [Parameter(Mandatory = $true)][string]$FabricWorkspaceId,
  [Parameter(Mandatory = $false)][ValidateSet("Admin","Member","Contributor","Viewer")] [string]$WorkspaceRole = "Contributor"
)

# Requires Fabric admin APIs enabled and caller with sufficient Fabric admin permissions.
$token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv

$body = @{
  principal = @{
    id = $FunctionPrincipalId
    type = "ServicePrincipal"
  }
  role = $WorkspaceRole
} | ConvertTo-Json -Depth 6

Invoke-RestMethod `
  -Method Post `
  -Uri "https://api.fabric.microsoft.com/v1/workspaces/$FabricWorkspaceId/roleAssignments" `
  -Headers @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" } `
  -Body $body
