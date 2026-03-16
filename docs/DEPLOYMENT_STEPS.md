# Deployment Steps

Use the config-driven deployment flow under `deploy/`.

## 1) Configure

Populate `deploy/deploy.config.toml` with:

- Azure subscription/location/resource group/prefix
- Optional explicit names (function app, storage account, service bus namespace)
- Existing Azure OpenAI and Document Intelligence resource IDs/endpoints
- Fabric workspace ID and bootstrap options
- Logic App callback URLs
- Mailbox assumptions (existing shared mailbox + sender mailboxes + connector identity UPN)

## 2) Deploy Infrastructure + Fabric Bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File "deploy/deploy-infra.ps1" -ConfigPath "deploy/deploy.config.toml"
```

This step:

- deploys infrastructure via Azure CLI + PowerShell
- provisions Flex Consumption Function App
- applies idempotent RBAC assignments
- bootstraps Fabric folders/notebooks/lakehouse/table
- sets Function App runtime settings including identity-based Service Bus trigger setting (`SERVICEBUS_CONNECTION__fullyQualifiedNamespace`)
- validates mailbox assumptions and prints Exchange permission reminder

## 3) Publish Function

```powershell
powershell -ExecutionPolicy Bypass -File "deploy/deploy-function.ps1" -ConfigPath "deploy/deploy.config.toml"
```

This step also uploads prompt files to blob storage (`prompts` container) so runtime prompt updates are cloud-managed.

## Exchange Online step (required)

Mailbox permissions are not Azure RBAC. In Exchange Online, grant the Logic App connector identity:

- `FullAccess` on the target shared mailbox
- `SendAs` on the missing-info sender mailbox
- `SendAs` on the rejection sender mailbox

## 4) Validate

- Send a processable email with an attachment to the monitored mailbox.
- Confirm Service Bus processing on `q-cqc-email-process`.
- Confirm writer command processing on `q-cqc-fabric-write`.
- Confirm Silver table writes in Fabric.
- Send a reply with missing fields and verify the update path.
