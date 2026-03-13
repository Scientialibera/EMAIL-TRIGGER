from __future__ import annotations

from src.common.models.contracts import QueueMessage
from src.processing_function.adapters.logic_app_client import LogicAppAdapter


def send_rejection_notice(
    queue_message: QueueMessage,
    reason: str,
    subject_template: str,
    body_template: str,
    thread_context: str,
    client: LogicAppAdapter,
) -> None:
    payload = {
        "internet_message_id": queue_message.internet_message_id,
        "thread_id": queue_message.thread_id,
        "correlation_id": queue_message.correlation_id,
        "recipient": queue_message.sender,
        "subject": subject_template.format(subject=queue_message.subject, thread_id=queue_message.thread_id),
        "body": body_template.format(
            subject=queue_message.subject,
            thread_id=queue_message.thread_id,
            reason=reason,
        ),
        "reason": reason,
        "thread_context": thread_context,
    }
    client.send_rejection_notice(payload)
