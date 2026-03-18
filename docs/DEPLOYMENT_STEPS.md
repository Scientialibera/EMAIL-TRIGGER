# Deployment Steps

Use the config-driven deployment flow under `deploy/`.

## 1) Configure

Populate `deploy/deploy.config.toml` with:

- Azure subscription/location/resource group/prefix
- Optional explicit names for all resources — if given, the script checks if they exist and reuses; if not, creates with that name; if empty, derives from prefix
- `[openai]` — toggle `deploy_openai_resources`, model deployment name/version/SKU
- `[docintel]` — toggle `deploy_docintel_resources`, SKU
- Fabric workspace ID and bootstrap options
- Logic App callback URLs
- Mailbox config (shared mailbox + sender mailboxes + connector identity UPN)

## 2) Deploy Infrastructure + Fabric Bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File "deploy/deploy-infra.ps1" -ConfigPath "deploy/deploy.config.toml"
```

This step:

- creates/reuses ALL Azure resources: RG, Storage, Service Bus, Azure OpenAI, Document Intelligence, Function App
- deploys Azure OpenAI as standalone `OpenAI` kind with custom subdomain
- deploys Document Intelligence as `AIServices` kind with custom subdomain
- validates custom subdomains (token auth with Managed Identity fails without them)
- creates OpenAI model deployment (create-if-missing)
- applies idempotent RBAC assignments (SB, Storage, AOAI, DocIntel)
- bootstraps Fabric folders/notebooks/lakehouse/table
- sets Function App runtime settings including identity-based Service Bus trigger setting (`SERVICEBUS_CONNECTION__fullyQualifiedNamespace`)

## 3) Exchange Online Setup

```powershell
powershell -ExecutionPolicy Bypass -File "deploy/deploy-exchange.ps1" -ConfigPath "deploy/deploy.config.toml" -AdminUpn "admin@yourdomain.com"
```

Creates shared mailboxes and grants the Logic App connector identity:
- `FullAccess` on the target shared mailbox
- `SendAs` on the missing-info and rejection sender mailboxes

## 4) Publish Function

```powershell
powershell -ExecutionPolicy Bypass -File "deploy/deploy-function.ps1" -ConfigPath "deploy/deploy.config.toml"
```

Publishes Python Function code and uploads prompt files to blob storage (`prompts` container).

## 5) Manual Step — Logic App Connector OAuth

The Office 365 Outlook connector requires a one-time sign-in. See `deploy/README.md` for details.

## 6) Validate

- Send a processable email with an attachment to the monitored mailbox.
- Confirm Service Bus processing on `q-cqc-email-process`.
- Confirm writer command processing on `q-cqc-fabric-write`.
- Confirm Silver table writes in Fabric.
- Send a reply with missing fields and verify the update path.

## What Is Idempotent

- Resource group
- Storage account + containers
- Service Bus namespace + queues (standard + session-enabled)
- Azure OpenAI account (standalone `OpenAI` kind) + model deployment
- Document Intelligence account (`AIServices` kind)
- Custom subdomains on AOAI and DocIntel (added to existing accounts if missing)
- Function App (Flex Consumption)
- RBAC role assignments
- Fabric workspace artifacts

## Critical Post-Deploy Checks

1. Verify `DOCINTEL_ENDPOINT` uses the custom subdomain form (`https://<name>.cognitiveservices.azure.com/`), not the regional endpoint
2. Verify `extensionBundle` is present in `host.json` — without it, Service Bus triggers silently fail
3. Verify Function App MI has `Cognitive Services OpenAI User` on AOAI and `Cognitive Services User` on DocIntel
