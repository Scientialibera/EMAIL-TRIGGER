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
- Azure OpenAI validity and schema extraction.
- Fabric notebook execution for Silver persistence and reply updates.

Core design constraints:
- Managed identity + `DefaultAzureCredential`.
- Configuration-driven schema/prompt/model behavior.
- Idempotency using `internet_message_id` + attachment hash.
- Ordered Fabric writes by publishing commands to a session-enabled writer queue (`session_id = thread_id`).
- DLQ-safe processing with correlation logging.
