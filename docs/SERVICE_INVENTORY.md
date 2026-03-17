# EMAIL-TRIGGER — End-to-End Service Inventory

Complete inventory of every service, resource, identity, table, mailbox, and connection required to run the CQC Intelligent Email Processor from zero to production.

---

## 1. Naming Convention Table

### Azure Resources

| # | Service Type | Dev Name | Prod Name | Notes |
|---|---|---|---|---|
| 1 | **Resource Group** | `rg-cqc-email-dev` | `rg-cqc-email-prod` | Container for all Azure resources |
| 2 | **Azure Function App** | `func-cqc-email-dev` | `func-cqc-email-prod` | Python 3.11, Flex Consumption, Functions v4 |
| 3 | **App Service Plan** | `asp-cqc-email-dev` | `asp-cqc-email-prod` | Flex Consumption (auto-created with Function App) |
| 4 | **Storage Account (Function)** | `stcqcemaildev` | `stcqcemailprod` | Function runtime storage + prompt blobs |
| 5 | **Blob Container — Prompts** | `prompts` | `prompts` | Holds versioned validity/extraction prompts |
| 6 | **Service Bus Namespace** | `sbns-cqc-email-dev` | `sbns-cqc-email-prod` | Standard tier; hosts both queues |
| 7 | **Service Bus Queue — Process** | `q-cqc-email-process` | `q-cqc-email-process` | Standard queue (no sessions) |
| 8 | **Service Bus Queue — Fabric Write** | `q-cqc-fabric-write` | `q-cqc-fabric-write` | Session-enabled (`session_id = thread_id`) |
| 9 | **Azure OpenAI Account** | `aoai-cqc-email-dev` | `aoai-cqc-email-prod` | Or shared AI Foundry resource |
| 10 | **AOAI Model Deployment** | `gpt-4o-dev` | `gpt-4o-prod` | Single deployment used for both validity and extraction; different prompts + function definitions per call |
| 12 | **Document Intelligence** | `di-cqc-email-dev` | `di-cqc-email-prod` | `prebuilt-read` model; OCR for PDF/DOCX/images |
| 13 | **Key Vault** | `kv-cqc-email-dev` | `kv-cqc-email-prod` | RBAC-authorized; stores any secrets if needed |
| 14 | **Application Insights** | `appi-cqc-email-dev` | `appi-cqc-email-prod` | Telemetry, traces by `correlation_id` |
| 15 | **Log Analytics Workspace** | `law-cqc-email-dev` | `law-cqc-email-prod` | Backend for App Insights |

### Logic Apps (Standard or Consumption)

| # | Service Type | Dev Name | Prod Name | Purpose |
|---|---|---|---|---|
| 16 | **Logic App — Prefilter** | `la-cqc-prefilter-dev` | `la-cqc-prefilter-prod` | Monitors shared mailbox, applies header rules, serializes to Service Bus |
| 17 | **Logic App — Rejection Email** | `la-cqc-rejection-dev` | `la-cqc-rejection-prod` | Sends rejection notices (header fail or validity fail) |
| 18 | **Logic App — Missing Info** | `la-cqc-missinginfo-dev` | `la-cqc-missinginfo-prod` | Sends request-for-information emails with thread context |
| 19 | **Logic App — Reply Monitor** | `la-cqc-replymon-dev` | `la-cqc-replymon-prod` | Monitors shared mailbox for replies, calls `ApplyEmailReplyUpdate` HTTP endpoint |

### Microsoft 365 / Exchange Online

| # | Service Type | Dev Name | Prod Name | Purpose |
|---|---|---|---|---|
| 20 | **Shared Mailbox (Inbound)** | `cqc-email-dev@contoso.com` | `cqc-email@contoso.com` | Receives supplier COA emails and replies |
| 21 | **Sender Mailbox — Missing Info** | `cqc-noreply-dev@contoso.com` | `cqc-noreply@contoso.com` | From address for request-for-information emails |
| 22 | **Sender Mailbox — Rejection** | `cqc-noreply-dev@contoso.com` | `cqc-noreply@contoso.com` | From address for rejection notices (can share with #21) |

### Microsoft Fabric

| # | Service Type | Dev Name | Prod Name | Purpose |
|---|---|---|---|---|
| 23 | **Fabric Workspace** | `ws-cqc-email-dev` | `ws-cqc-email-prod` | Container for lakehouse + notebooks |
| 24 | **Fabric Lakehouse** | `emailtrigger_lakehouse` | `emailtrigger_lakehouse` | Houses the Silver Delta table |
| 25 | **Delta Table — Silver** | `dbo.cqc_email_silver` | `dbo.cqc_email_silver` | Append-only CDC table with `latest_update` flag |
| 26 | **Fabric Notebook — Writer** | `cqc_silver_writer_main` | `cqc_silver_writer_main` | Executes `process_email_cdc` / `apply_reply_update_cdc` |
| 27 | **Fabric Notebook — Writer Module** | `cqc_silver_module` | `cqc_silver_module` | Reusable CDC logic imported by writer |
| 28 | **Fabric Notebook — Bootstrap** | `cqc_silver_bootstrap_main` | `cqc_silver_bootstrap_main` | One-time table creation |
| 29 | **Fabric Notebook — Bootstrap Module** | `cqc_silver_bootstrap_module` | `cqc_silver_bootstrap_module` | `ensure_silver_table` logic |

---

## 2. Identities & Service Principals

| # | Identity Type | Name / Description | Where Created | Purpose |
|---|---|---|---|---|
| 30 | **System-Assigned Managed Identity** | Auto-created with Function App | `az functionapp identity assign` | Function App authenticates to all Azure services via `DefaultAzureCredential` |
| 31 | **System-Assigned Managed Identity** | Auto-created with each Logic App | Logic App resource creation | Logic Apps authenticate to Exchange Online, Service Bus |
| 32 | **Exchange Online Service Account** | UPN used by Logic App connectors | Exchange Admin Center | Logic App connector identity for mailbox access (`FullAccess`, `SendAs`) |

> **No service principals are needed.** The entire solution uses system-assigned managed identities with `DefaultAzureCredential`. No client secrets, no certificates, no rotation burden.

---

## 3. RBAC Role Assignments

Every assignment uses the **Function App's Managed Identity** as principal unless noted.

| # | Principal | Target Resource | Role | Role Definition ID |
|---|---|---|---|---|
| R1 | Function MI | Service Bus Queue `q-cqc-email-process` | Azure Service Bus Data Receiver | `4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0` |
| R2 | Function MI | Service Bus Queue `q-cqc-fabric-write` | Azure Service Bus Data Receiver | `4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0` |
| R3 | Function MI | Service Bus Queue `q-cqc-fabric-write` | Azure Service Bus Data Sender | `69a216fc-b8fb-44d8-bc22-1f3c2cd27a39` |
| R4 | Function MI | Azure OpenAI Account | Cognitive Services OpenAI User | `5e0bd9bd-7b93-4f28-af87-19fc36ad61bd` |
| R5 | Function MI | Document Intelligence | Cognitive Services User | `a97b65f3-24c7-4388-baec-2e87135dc908` |
| R6 | Function MI | Storage Account | Storage Blob Data Reader | `2a2b9908-6ea1-4ae2-8e65-a410df84e7d1` |
| R7 | Function MI | Fabric Workspace | Contributor (workspace role) | Assigned via Fabric Admin API |
| R8 | Logic App MI (Prefilter) | Service Bus Namespace | Azure Service Bus Data Sender | `69a216fc-b8fb-44d8-bc22-1f3c2cd27a39` |
| R9 | Logic App MI (Reply Monitor) | Function App | n/a (uses Function Key) | HTTP trigger auth |
| R10 | Deployer (user/SP) | Resource Group | Contributor | For `az deployment group create` |
| R11 | Deployer (user/SP) | Storage Account | Storage Blob Data Owner | Upload prompts to blob container |

---

## 4. Exchange Online Permissions (non-Azure RBAC)

| # | Identity | Mailbox | Permission | How to Set |
|---|---|---|---|---|
| E1 | Logic App connector UPN | Shared Mailbox (Inbound) | `FullAccess` | `Add-MailboxPermission` |
| E2 | Logic App connector UPN | Sender Mailbox (Missing Info) | `SendAs` | `Add-RecipientPermission` |
| E3 | Logic App connector UPN | Sender Mailbox (Rejection) | `SendAs` | `Add-RecipientPermission` |

---

## 5. Azure Function App — Functions Inside

| Function Name | Trigger | Input | Output |
|---|---|---|---|
| `ProcessEmailMessage` | Service Bus Queue (`q-cqc-email-process`) | Serialized email JSON from Logic App Prefilter | Enqueues `FabricWriteCommand` to `q-cqc-fabric-write` |
| `ApplyEmailReplyUpdate` | HTTP POST (`/api/apply-reply-update`) | Correlated field updates from Reply Monitor Logic App | Enqueues `FabricWriteCommand` to `q-cqc-fabric-write` |
| `ProcessFabricWriteCommand` | Service Bus Queue (`q-cqc-fabric-write`, sessions) | `FabricWriteCommand` message | Runs Fabric Notebook via REST API |

---

## 6. Fabric Silver Table Schema (`dbo.cqc_email_silver`)

| Column | Type | Description |
|---|---|---|
| `thread_id` | `STRING` | Email thread identifier (partition key for CDC) |
| `email_id` | `STRING` | `internet_message_id` |
| `status` | `STRING` | `processed`, `missing_info`, `reply_updated` |
| `record_json` | `STRING` | JSON — extracted fields as arrays of `{value, confidence}` |
| `latest_update` | `BOOLEAN` | `true` for the most recent row per thread |
| `cdc_operation` | `STRING` | `process_email_cdc` or `apply_reply_update_cdc` |
| `updated_by_flow` | `STRING` | Which function wrote this row |
| `correlation_id` | `STRING` | End-to-end trace ID |
| `created_at` | `TIMESTAMP` | Row creation time |
| `last_modified` | `TIMESTAMP` | Last modification time |

---

## 7. Configuration Files (deployed with Function)

| File / Blob | Purpose |
|---|---|
| `prompts/validity/validity_v1.txt` | LLM prompt for validity check (approve/reject) |
| `prompts/extraction/extraction_v1.txt` | LLM prompt for structured field extraction |
| `src/schemas/extraction/coa_v1.json` | JSON schema defining COA fields (arrays of `{value, confidence}`) |
| `src/config/email_header_rules.json` | `processable_headers` and `request_info_header` |
| `src/config/email_templates.json` | Templated subject/body for rejection and missing-info emails |
| `src/model_profiles/default.yaml` | Model deployment names, temperature, max tokens |

---

## 8. Network / Connectivity Summary

```
Shared Mailbox ──► Logic App Prefilter ──► Service Bus (process queue)
                                              │
                                              ▼
                                      Azure Function App
                                       ├─► Document Intelligence (REST)
                                       ├─► Azure OpenAI (REST)
                                       ├─► Storage Account (blob read)
                                       ├─► Service Bus (fabric-write queue, send)
                                       └─► Logic Apps (HTTP POST for emails)
                                              │
                              Service Bus (fabric-write queue, receive)
                                              │
                                              ▼
                                      Azure Function App
                                       └─► Fabric REST API ──► Notebook ──► Lakehouse Silver
```

All connections use **Managed Identity + `DefaultAzureCredential`** except:
- Logic App to Exchange Online: Office 365 connector with delegated permissions
- Logic App Reply Monitor to Function App: HTTP with Function Key

---

## 9. Total Resource Count

| Category | Count |
|---|---|
| Azure Resources (RG, Function, Storage, SB, AOAI, DI, KV, AppInsights, LAW) | 15 |
| Logic Apps | 4 |
| Microsoft 365 Mailboxes | 2–3 |
| Fabric Resources (Workspace, Lakehouse, Notebooks, Table) | 7 |
| Managed Identities | 5 (1 Function + 4 Logic Apps) |
| RBAC Assignments | 11 |
| Exchange Permissions | 3 |
| **Total distinct resources/configurations** | **~47** |
