# Operations Runbook

## Monitoring

- Application Insights traces (filter by `correlation_id`)
- Service Bus queue depth and dead-letter count
- Function execution failures and duration
- Fabric notebook job failures

## Common Failures

- `AuthError`: Managed identity missing required role.
- `SchemaMismatch`: Model output does not match configured extraction schema.
- `DependencyTimeout`: Retry exhausted for AOAI, Doc Intelligence, or Fabric API.
- `ValidationError`: Invalid queue/reply payload.

## DLQ Procedure

1. Inspect dead-letter reason and correlation id.
2. Fix root cause (RBAC/config/schema mismatch).
3. Replay message from DLQ to main queue using approved ops tool.
4. Verify record status in Fabric Silver.

## Change Management

- Field changes: update `src/schemas/extraction/*.json`.
- Prompt changes: update `src/prompts/**`.
- Model switch: update `src/model_profiles/*.yaml` and set `ACTIVE_MODEL_PROFILE`.
