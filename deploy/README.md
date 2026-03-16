# Deployment (Config-Driven)

This folder provides an idempotent, split deployment flow with a single config file:

1. `deploy/deploy-infra.ps1`  
   - deploys Azure infra using Azure CLI (no Bicep)
   - creates Flex Consumption Function App
   - enforces RBAC assignments idempotently
   - bootstraps Fabric artifacts (folders, notebooks, lakehouse/table)
   - applies Function App settings from config (including MI-based Service Bus trigger connection)

2. `deploy/deploy-function.ps1`  
   - publishes Python Function code
   - seeds prompt files to the prompts blob container
   - syncs Function trigger metadata

## Configure once

Update `deploy/deploy.config.toml`:

- Azure subscription/resource group/location/prefix
- Optional explicit resource names for storage/service bus/function app
- Existing AOAI and DocIntel resource IDs + endpoints
- Fabric workspace ID and folder/lakehouse/notebook/table preferences
- Logic App callback URLs
- Mailbox assumptions (existing shared mailbox + sender mailboxes + connector identity UPN)

## Run

```powershell
powershell -ExecutionPolicy Bypass -File "deploy/deploy-infra.ps1" -ConfigPath "deploy/deploy.config.toml"
powershell -ExecutionPolicy Bypass -File "deploy/deploy-function.ps1" -ConfigPath "deploy/deploy.config.toml"
```

## Exchange Online prerequisite (not Azure RBAC)

`deploy-infra.ps1` validates mailbox assumptions but cannot grant mailbox permissions in Exchange Online.
You must grant the Logic App connector identity:

- `FullAccess` on the target shared mailbox
- `SendAs` on the missing-info sender mailbox
- `SendAs` on the rejection sender mailbox

## Fabric Notebook Structure

The bootstrap creates this structure in the Fabric workspace:

- `notebooks/main`
- `notebooks/modules`

And pushes notebook sources from:

- `deploy/assets/fabric/notebooks/main`
- `deploy/assets/fabric/notebooks/modules`
