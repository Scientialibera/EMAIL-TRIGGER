# Bicep Deployment

## Deploy

```powershell
az deployment group create `
  --resource-group rg-cqc-email-processor-dev `
  --template-file infra/bicep/main.bicep `
  --parameters infra/bicep/parameters/dev.bicepparam
```

## Notes

- Some access paths (Fabric workspace role assignment, Logic App managed connector binding) are completed through scripts in `scripts/az`.
- `aoaiInvokeRoleDefinitionId` and `docIntelInvokeRoleDefinitionId` are configurable because tenant policies can vary by assigned role.
- Service Bus deploys two queues:
  - `q-cqc-email-process` for inbound processing
  - `q-cqc-fabric-write` (session-enabled) for ordered Fabric write commands
