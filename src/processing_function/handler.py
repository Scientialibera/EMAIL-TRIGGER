from __future__ import annotations

import logging

from src.common.config.settings import get_settings
from src.common.logging.telemetry import log_event
from src.common.utils.validation import compute_missing_fields
from src.processing_function.adapters.doc_intelligence_client import DocumentIntelligenceAdapter
from src.processing_function.adapters.fabric_write_queue_client import FabricWriteQueueAdapter
from src.processing_function.adapters.logic_app_client import LogicAppAdapter
from src.processing_function.adapters.openai_client import AzureOpenAIAdapter
from src.processing_function.adapters.service_bus_client import parse_service_bus_message
from src.processing_function.pipeline.context_builder import build_llm_context
from src.processing_function.pipeline.convert_to_text import convert_attachments_to_text
from src.processing_function.pipeline.extraction import extract_record
from src.processing_function.pipeline.missing_info import request_missing_information
from src.processing_function.pipeline.multimodal import collect_image_data_urls
from src.processing_function.pipeline.persist import persist_record
from src.processing_function.pipeline.prefilter import is_processable
from src.processing_function.pipeline.rejection_notice import send_rejection_notice
from src.processing_function.pipeline.validity_check import evaluate_validity


def process_email_message(message_body: bytes, logger: logging.Logger) -> None:
    settings = get_settings()
    queue_message = parse_service_bus_message(message_body)
    correlation_id = queue_message.correlation_id

    log_event(logger, "processing_start", correlation_id, message_id=queue_message.message_id)

    if not is_processable(queue_message, settings.processable_headers):
        log_event(logger, "processing_skipped_prefilter", correlation_id, status="rejected")
        return

    doc_client = DocumentIntelligenceAdapter(settings.docintel_endpoint)
    ai_client = AzureOpenAIAdapter(settings)
    fabric_client = FabricWriteQueueAdapter(
        namespace_fqdn=settings.servicebus_namespace_fqdn,
        queue_name=settings.fabric_write_queue_name,
    )
    logic_client = LogicAppAdapter(
        invoke_url=settings.missing_info_logicapp_url,
        rejection_invoke_url=settings.rejection_notice_logicapp_url,
    )

    extracted_attachments, attachment_names, _attachment_bytes = convert_attachments_to_text(
        queue_message.attachment_refs, doc_client
    )
    llm_context = build_llm_context(queue_message, extracted_attachments)
    image_data_urls = collect_image_data_urls(queue_message, extracted_attachments)

    is_valid, reason = evaluate_validity(llm_context, image_data_urls, ai_client)
    if not is_valid:
        send_rejection_notice(
            queue_message=queue_message,
            reason=reason,
            subject_template=settings.rejection_subject_template,
            body_template=settings.rejection_body_template,
            thread_context=llm_context,
            client=logic_client,
        )
        log_event(logger, "validity_rejected", correlation_id, reason=reason)
        return

    record = extract_record(
        email_id=queue_message.internet_message_id,
        thread_id=queue_message.thread_id,
        receive_timestamp=queue_message.received_timestamp,
        attachment_names=attachment_names,
        text=llm_context,
        image_data_urls=image_data_urls,
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
        request_missing_information(
            queue_message=queue_message,
            record=record,
            request_info_header=settings.request_info_header,
            subject_template=settings.missing_info_subject_template,
            body_template=settings.missing_info_body_template,
            thread_context=llm_context,
            client=logic_client,
        )
        log_event(
            logger,
            "missing_info_requested",
            correlation_id,
            missing_fields=record.missing_fields,
        )

    log_event(logger, "processing_complete", correlation_id, status=record.status)
