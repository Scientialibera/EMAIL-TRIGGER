from __future__ import annotations

from src.common.models.contracts import ExtractionRecord, QueueMessage
from src.processing_function.adapters.logic_app_client import LogicAppAdapter


def request_missing_information(
    queue_message: QueueMessage, record: ExtractionRecord, client: LogicAppAdapter
) -> None:
    payload = {
        "email_id": record.email_id,
        "thread_id": record.thread_id,
        "correlation_id": record.correlation_id,
        "missing_fields": record.missing_fields,
        "recipient": queue_message.sender,
        "subject": f"Missing information required: {queue_message.subject}",
    }
    client.send_missing_info_request(payload)
