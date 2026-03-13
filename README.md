# CQC Email Processor

Enterprise-grade Azure email processing service that:
- Prefilters inbound emails with Logic App rules.
- Processes eligible messages through Service Bus and Azure Functions.
- Converts attachments to text, validates, and extracts COA fields with confidence.
- Persists records to Fabric Silver via notebook/job execution.
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
