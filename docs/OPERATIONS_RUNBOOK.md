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

## Change Management

- Field changes: update `src/schemas/extraction/*.json`.
- Prompt changes: update `src/prompts/**`.
- Model switch: update `src/model_profiles/*.yaml` and set `ACTIVE_MODEL_PROFILE`.
- Header rule changes: update `src/config/email_header_rules.json`.
- Email template changes: update `src/config/email_templates.json`.
- Fabric CDC notebook logic: update `notebooks/cqc_fabric_silver_writer.py` (single notebook, two operations).
- Ordered writer queue behavior: update `src/processing_function/adapters/fabric_write_queue_client.py` and `src/fabric_writer_function/handler.py`.
