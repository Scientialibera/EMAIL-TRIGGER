# CQC Email Processor

Enterprise-grade Azure email processing service that:
- Prefilters inbound emails with Logic App rules.
- Processes eligible messages through Service Bus and Azure Functions.
- Converts attachments to text, validates, and extracts COA fields with confidence.
- Enqueues Fabric write commands to a dedicated Service Bus writer queue.
- Persists records to Fabric Silver via a single writer function + notebook/job execution.
- Sends missing-information requests and applies reply-based updates without rerunning AI.

## Repository Layout

```text
infra/               # Bicep templates and env parameters
scripts/             # Post-deploy operational scripts
src/                 # Azure Function app and modules
tests/               # Unit, contract, and integration tests
docs/                # Design + deployment + runbook docs
```

## Runtime

- Python 3.11+
- Azure Functions v4 (Python v2 programming model)
- Managed identity authentication through `DefaultAzureCredential`

## Quick Start (Local)

1. Create and activate a virtual environment.
2. Install dependencies:
   - `pip install -e .[dev]`
3. Copy local settings template:
   - `cp local.settings.json.example local.settings.json`
4. Set required environment values.
5. Run:
   - `func start`

## Deployment

Use Bicep templates under `infra/bicep` plus operational scripts under `scripts/az`.

Step-by-step operator commands are in `docs/DEPLOYMENT_STEPS.md`.

Operator scripts included:
- `scripts/az/00_deploy_infra.ps1` - deploys resource group + Bicep stack
- `scripts/az/01_post_deploy_rbac.ps1` - sets Service Bus and optional dependency RBAC
- `scripts/az/02_add_function_mi_to_fabric.ps1` - adds Function MI to Fabric workspace role
- `scripts/az/03_configure_logicapp_connections.ps1` - configures Logic App connector references
- `scripts/az/04_seed_app_settings.ps1` - applies required Function app settings
- `scripts/az/05_publish_function.ps1` - publishes Function code
- `scripts/az/99_full_deploy.ps1` - runs end-to-end flow in one command
