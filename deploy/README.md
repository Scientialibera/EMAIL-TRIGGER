# Deployment (Config-Driven)

This folder provides an idempotent, split deployment flow with a single config file:

1. `deploy/deploy-infra.ps1`  
   - deploys ALL Azure infra using Azure CLI (no Bicep)
   - creates/reuses Azure OpenAI (standalone `OpenAI` kind with custom subdomain)
   - creates/reuses Document Intelligence (`AIServices` kind with custom subdomain)
   - deploys OpenAI model deployment (create-if-missing)
   - creates Flex Consumption Function App
   - enforces RBAC assignments idempotently
   - validates custom subdomains (token auth fails without them)
   - bootstraps Fabric artifacts (folders, notebooks, lakehouse/table)
   - applies Function App settings from config (including MI-based Service Bus trigger connection)

2. `deploy/deploy-function.ps1`  
   - publishes Python Function code
   - seeds prompt files to the prompts blob container
   - syncs Function trigger metadata

3. `deploy/deploy-exchange.ps1`  
   - installs/imports the ExchangeOnlineManagement module
   - creates shared mailboxes (inbound + sender) if they don't exist
   - grants FullAccess and SendAs permissions to the connector service account
   - enables sent-message copy on the sender mailbox
   - validates all permissions

## Configure once

Update `deploy/deploy.config.toml`:

- Azure subscription/resource group/location/prefix
- Optional explicit resource names — if given, the script checks if it exists and reuses it; if it doesn't exist, creates with that name; if left empty, derives a name from the prefix
- `[openai]` — model deployment name, version, SKU, toggle `deploy_openai_resources`
- `[docintel]` — SKU, toggle `deploy_docintel_resources`
- Fabric workspace ID and folder/lakehouse/notebook/table preferences
- Logic App callback URLs
- Mailbox addresses and connector service account UPN (under `[mailbox]`)

## Run

```powershell
# 1. Deploy Azure infra, RBAC, Fabric, and app settings
powershell -ExecutionPolicy Bypass -File "deploy/deploy-infra.ps1" -ConfigPath "deploy/deploy.config.toml"

# 2. Create Exchange Online mailboxes and grant permissions
powershell -ExecutionPolicy Bypass -File "deploy/deploy-exchange.ps1" -ConfigPath "deploy/deploy.config.toml" -AdminUpn "admin@yourdomain.com"

# 3. Publish Function code and seed prompts
powershell -ExecutionPolicy Bypass -File "deploy/deploy-function.ps1" -ConfigPath "deploy/deploy.config.toml"
```

## Manual step — Logic App connector authorization

The Office 365 Outlook connector requires a **one-time OAuth sign-in** that
cannot be scripted. After running `deploy-exchange.ps1` and waiting up to
**2 hours** for Exchange permission replication:

1. Open each Logic App in the **Azure Portal**
2. Go to **Logic App Designer**
3. Click the Office 365 Outlook connector → **Change connection**
4. Sign in with the service account (the `logic_app_connector_identity_upn`
   from your config, e.g. `svc-cqc-logicapp@yourdomain.com`)
5. Set the **Original Mailbox Address** to the appropriate shared mailbox
6. **Save** the Logic App

Repeat for each Logic App:

| Logic App | Connector Type | Mailbox |
|---|---|---|
| Prefilter | Trigger — When a new email arrives in shared mailbox | Inbound (`target_shared_mailbox`) |
| Missing Info | Action — Send email from shared mailbox | Sender (`missing_info_sender_mailbox`) |
| Rejection | Action — Send email from shared mailbox | Sender (`rejection_sender_mailbox`) |
| Reply Monitor | Trigger — When a new email arrives in shared mailbox | Inbound (`target_shared_mailbox`) |

After this one-time step the pipeline runs fully programmatically.

## Fabric Notebook Structure

The bootstrap creates this structure in the Fabric workspace:

- `notebooks/main`
- `notebooks/modules`

And pushes notebook sources from:

- `deploy/assets/fabric/notebooks/main`
- `deploy/assets/fabric/notebooks/modules`
