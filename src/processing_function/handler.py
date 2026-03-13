from __future__ import annotations

import logging

from src.common.config.settings import get_settings
from src.common.logging.telemetry import log_event
from src.common.utils.idempotency import build_idempotency_key, compute_attachment_hash
from src.common.utils.validation import compute_missing_fields
from src.processing_function.adapters.doc_intelligence_client import DocumentIntelligenceAdapter
from src.processing_function.adapters.fabric_client import FabricNotebookAdapter
from src.processing_function.adapters.logic_app_client import LogicAppAdapter
from src.processing_function.adapters.openai_client import AzureOpenAIAdapter
from src.processing_function.adapters.service_bus_client import parse_service_bus_message
from src.processing_function.pipeline.convert_to_text import convert_attachments_to_text
from src.processing_function.pipeline.extraction import extract_record
from src.processing_function.pipeline.missing_info import request_missing_information
from src.processing_function.pipeline.persist import persist_record
from src.processing_function.pipeline.prefilter import is_processable
from src.processing_function.pipeline.validity_check import evaluate_validity


def process_email_message(message_body: bytes, logger: logging.Logger) -> None:
    settings = get_settings()
    queue_message = parse_service_bus_message(message_body)
    correlation_id = queue_message.correlation_id

    log_event(logger, "processing_start", correlation_id, message_id=queue_message.message_id)

    if not is_processable(queue_message):
        log_event(logger, "processing_skipped_prefilter", correlation_id, status="rejected")
        return

    doc_client = DocumentIntelligenceAdapter(settings.docintel_endpoint)
    ai_client = AzureOpenAIAdapter(settings)
    fabric_client = FabricNotebookAdapter(settings.fabric_notebook_job_endpoint)
    logic_client = LogicAppAdapter(settings.missing_info_logicapp_url)

    text, attachment_names, attachment_bytes = convert_attachments_to_text(
        queue_message.attachment_refs, doc_client
    )

    attachment_hashes = [compute_attachment_hash(x) for x in attachment_bytes]
    idem_key = build_idempotency_key(queue_message.internet_message_id, attachment_hashes)
    log_event(logger, "idempotency_key_computed", correlation_id, idempotency_key=idem_key)

    is_valid, reason = evaluate_validity(text, ai_client)
    if not is_valid:
        log_event(logger, "validity_rejected", correlation_id, reason=reason)
        return

    record = extract_record(
        email_id=queue_message.internet_message_id,
        thread_id=queue_message.thread_id,
        receive_timestamp=queue_message.received_timestamp,
        attachment_names=attachment_names,
        text=text,
        schema=settings.extraction_schema,
        model_name=settings.profile.extraction_model,
        correlation_id=correlation_id,
        client=ai_client,
    )

    required_fields = settings.extraction_schema.get("required_fields", [])
    record.missing_fields = compute_missing_fields(
        record, required_fields, settings.confidence_threshold_required
    )
    record.status = "missing_info" if record.missing_fields else "processed"

    persist_record(
        record=record,
        fabric_workspace_id=settings.fabric_workspace_id,
        lakehouse_id=settings.fabric_lakehouse_id,
        table_name=settings.fabric_silver_table,
        client=fabric_client,
    )

    if record.missing_fields:
        request_missing_information(queue_message=queue_message, record=record, client=logic_client)
        log_event(
            logger,
            "missing_info_requested",
            correlation_id,
            missing_fields=record.missing_fields,
        )

    log_event(logger, "processing_complete", correlation_id, status=record.status)
