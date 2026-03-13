# Deployment Steps

This repository now includes scripts to cover all three expected outcomes:
- Deploy infrastructure
- Set permissions/integrations
- Deploy Function code

## 1) Deploy Infrastructure (Bicep)

```powershell
./scripts/az/00_deploy_infra.ps1 `
  -SubscriptionId <subscription-id> `
  -ResourceGroup rg-cqc-email-processor-dev `
  -Location eastus2 `
  -Environment dev `
  -DeploymentName cqc-email-infra
```

## 2) Finalize Access and Integrations

Run post-deploy scripts in sequence:

1. `scripts/az/01_post_deploy_rbac.ps1`
2. `scripts/az/02_add_function_mi_to_fabric.ps1`
3. `scripts/az/03_configure_logicapp_connections.ps1`
4. `scripts/az/04_seed_app_settings.ps1`

The app settings step must include:
- `SERVICEBUS_NAMESPACE_FQDN`
- `SERVICEBUS_QUEUE_NAME`
- `FABRIC_WRITE_QUEUE_NAME`

## 3) Deploy Function Code

```powershell
./scripts/az/05_publish_function.ps1 `
  -ResourceGroup rg-cqc-email-processor-dev `
  -DeploymentName cqc-email-infra
```

## 4) Validate

- Send a processable email with attachment to the monitored mailbox.
- Confirm Service Bus message consumption.
- Confirm command message appears in `q-cqc-fabric-write`.
- Confirm `ProcessFabricWriteCommand` consumes command messages in order.
- Confirm Fabric Silver write via notebook job.
- Send reply email with missing fields and verify `updated` status path.

## Optional: Single-command full deployment

```powershell
./scripts/az/99_full_deploy.ps1 `
  -SubscriptionId <subscription-id> `
  -ResourceGroup rg-cqc-email-processor-dev `
  -Location eastus2 `
  -Environment dev `
  -DeploymentName cqc-email-infra `
  -FabricWorkspaceId <fabric-workspace-id> `
  -ServiceBusConnectionResourceId <servicebus-connector-resource-id> `
  -OfficeConnectionResourceId <office-connector-resource-id> `
  -ServiceBusNamespaceFqdn <namespace>.servicebus.windows.net `
  -AoaiEndpoint https://<aoai>.openai.azure.com `
  -DocIntelEndpoint https://<docintel>.cognitiveservices.azure.com `
  -FabricNotebookJobEndpoint https://api.fabric.microsoft.com/v1/workspaces/<ws>/items/<notebook>/jobs/instances?jobType=RunNotebook `
  -FabricLakehouseId <lakehouse-id> `
  -FabricSilverTable dbo.cqc_email_silver `
  -MissingInfoLogicAppUrl https://<logic-app-invoke-url>
```
