# Operations Runbook

## Monitoring

- Application Insights traces (filter by `correlation_id`)
- Service Bus queue depth and dead-letter count
- Fabric write queue session backlog (`q-cqc-fabric-write`)
- Function execution failures and duration
- Fabric notebook job failures

## Common Failures

- `AuthError`: Managed identity missing required role.
- `SchemaMismatch`: Model output does not match configured extraction schema.
- `DependencyTimeout`: Retry exhausted for AOAI, Doc Intelligence, or Fabric API.
- `ValidationError`: Invalid queue/reply payload.

## Validity Gate Policy

- Current rule: reject only when supplier name is missing.
- Do not reject for missing analyte/table values; those are completed through request-for-information flow.
- To change rejection logic, update `src/prompts/validity/validity_v1.txt` in the "Decision policy" section.

## DLQ Procedure

1. Inspect dead-letter reason and correlation id.
2. Fix root cause (RBAC/config/schema mismatch).
3. Replay message from DLQ to main queue using approved ops tool.
4. Verify record status in Fabric Silver.

## Infrastructure Requirements

### Extension Bundle (host.json)
The `extensionBundle` section in `host.json` is **mandatory**. Without it, Service Bus trigger bindings fail to register and the Function App silently ignores queue messages.

### Document Intelligence — Custom Subdomain
Token-based authentication (Managed Identity) requires a **custom subdomain** on the Cognitive Services account. The regional endpoint (e.g. `https://eastus2.api.cognitive.microsoft.com/`) does **not** support token auth. The deploy script enforces this automatically; ensure the `DOCINTEL_ENDPOINT` uses the form `https://<account-name>.cognitiveservices.azure.com/`.

### Document Intelligence — SDK
Uses `azure-ai-documentintelligence` (not the legacy `azure-ai-formrecognizer`). The new SDK uses `DocumentIntelligenceClient` and `AnalyzeDocumentRequest(bytes_source=...)`.

### Azure OpenAI — Authentication
Use `get_bearer_token_provider` from `azure.identity` with scope `https://cognitiveservices.azure.com/.default` for the `openai` Python SDK. Raw token via `get_access_token()` also works for REST calls.

### PyMuPDF — Multimodal Page Rendering
PDF pages are rendered to PNG images using PyMuPDF (`fitz`) for multimodal LLM input. Both the OCR text and the page images are sent to the LLM for extraction accuracy.

### Service Bus Session Queues
The fabric-write queue uses sessions (`session_id = thread_id`) to ensure ordered processing per email thread. The Function App must have `maxConcurrentSessions` and `maxConcurrentCalls` configured in `host.json`.

## Configuration Reference

| Setting | Default | Behavior |
|---|---|---|
| `CONFIDENCE_THRESHOLD_REQUIRED` | `0.97` | Minimum confidence score (0–1) an extracted field must meet to be accepted. Fields below this threshold are flagged as low-confidence and may trigger a request-for-information email to the sender. |
| `ACTIVE_EXTRACTION_SCHEMA` | `coa_v1` | Selects which JSON schema file under `src/schemas/extraction/` defines the expected COA fields. Allows versioned schema rollouts without code changes. |
| `ACTIVE_MODEL_PROFILE` | `default` | Selects the YAML model profile under `src/model_profiles/` that maps logical roles (validity, extraction) to specific AOAI deployment names, temperature, and max_tokens. |
| `FABRIC_NOTEBOOK_POLL_SECONDS` | `10` | Interval in seconds between status polls when waiting for a Fabric notebook job to complete. |
| `FABRIC_NOTEBOOK_WAIT_TIMEOUT_SECONDS` | `1800` | Maximum wait time (30 min) before a Fabric notebook job is considered timed out. |

## Change Management

- Field changes: update `src/schemas/extraction/*.json`.
- Prompt changes: update `src/prompts/**`.
- Model switch: update `src/model_profiles/*.yaml` and set `ACTIVE_MODEL_PROFILE`.
- Header rule changes: update `src/config/email_header_rules.json`.
- Email template changes: update `src/config/email_templates.json`.
- Fabric CDC notebook logic: update `notebooks/cqc_fabric_silver_writer.py` (single notebook, two operations).
- Ordered writer queue behavior: update `src/processing_function/adapters/fabric_write_queue_client.py` and `src/fabric_writer_function/handler.py`.
