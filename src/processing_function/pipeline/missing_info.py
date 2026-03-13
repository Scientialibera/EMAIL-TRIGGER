from __future__ import annotations

from src.common.models.contracts import ExtractionRecord, QueueMessage
from src.processing_function.adapters.logic_app_client import LogicAppAdapter


def request_missing_information(
    queue_message: QueueMessage,
    record: ExtractionRecord,
    request_info_header: str,
    subject_template: str,
    body_template: str,
    thread_context: str,
    client: LogicAppAdapter,
) -> None:
    missing_fields_text = ", ".join(record.missing_fields)
    payload = {
        "email_id": record.email_id,
        "thread_id": record.thread_id,
        "correlation_id": record.correlation_id,
        "missing_fields": record.missing_fields,
        "recipient": queue_message.sender,
        "subject": subject_template.format(subject=queue_message.subject, thread_id=record.thread_id),
        "body": body_template.format(
            subject=queue_message.subject,
            thread_id=record.thread_id,
            missing_fields=missing_fields_text,
        ),
        "header_name": request_info_header,
        "thread_context": thread_context,
        "thread_messages": [m.model_dump() for m in queue_message.thread_messages],
    }
    client.send_missing_info_request(payload)
