# Technical Design Document
## CQC Intelligent Email Processor

Version: 1.0  
Date: 2026-03-13  
Author: Argano

This repository implements the CQC email processor architecture:
- Logic App prefilter and orchestration entry.
- Service Bus durable queues (process queue + Fabric writer command queue).
- Azure Function `ProcessEmailMessage`.
- Azure Function `ApplyEmailReplyUpdate`.
- Azure Function `ProcessFabricWriteCommand` (single writer consumer).
- Azure Document Intelligence text extraction.
- Azure OpenAI validity function-call (`approved`, `reason`) and schema extraction.
- Fabric notebook execution for Silver persistence and reply updates.

Core design constraints:
- Managed identity + `DefaultAzureCredential`.
- Configuration-driven schema/prompt/model behavior.
- Configurable rejection/missing-info email templates.
- Idempotency using `internet_message_id` + attachment hash.
- Ordered Fabric writes by publishing commands to a session-enabled writer queue (`session_id = thread_id`).
- DLQ-safe processing with correlation logging.
- Multimodal prompt context: structured thread text + attachment/email images when available.

## Current Validity Policy

- The validity gate currently rejects only when supplier name is missing or cannot be identified.
- Other missing fields (for example moisture, cadmium, lead) do not cause validity rejection and are handled through missing-information workflow.
- This policy is defined in `src/prompts/validity/validity_v1.txt` under the "Decision policy" section and is intentionally easy to update.
