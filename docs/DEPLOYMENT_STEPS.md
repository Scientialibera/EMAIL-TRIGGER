# Deployment Steps

## 1) Deploy Infrastructure (Bicep)

```powershell
az login
az account set --subscription <subscription-id>

az deployment group create `
  --resource-group rg-cqc-email-processor-dev `
  --template-file infra/bicep/main.bicep `
  --parameters infra/bicep/parameters/dev.bicepparam
```

## 2) Finalize Access and Integrations

Run post-deploy scripts in sequence:

1. `scripts/az/01_post_deploy_rbac.ps1`
2. `scripts/az/02_add_function_mi_to_fabric.ps1`
3. `scripts/az/03_configure_logicapp_connections.ps1`
4. `scripts/az/04_seed_app_settings.ps1`

## 3) Deploy Function Code

```powershell
func azure functionapp publish <func-app-name> --python
```

## 4) Validate

- Send a processable email with attachment to the monitored mailbox.
- Confirm Service Bus message consumption.
- Confirm Fabric Silver write via notebook job.
- Send reply email with missing fields and verify `updated` status path.
