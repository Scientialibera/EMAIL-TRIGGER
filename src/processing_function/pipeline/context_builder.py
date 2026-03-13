from __future__ import annotations

from src.common.models.contracts import QueueMessage, ThreadMessage


def _safe_text(value: str | None) -> str:
    if value is None:
        return "(not provided)"
    trimmed = value.strip()
    return trimmed if trimmed else "(empty)"


def _current_message_from_queue(queue_message: QueueMessage) -> ThreadMessage:
    return ThreadMessage(
        message_id=queue_message.message_id,
        subject=queue_message.subject,
        sender=queue_message.sender,
        received_timestamp=queue_message.received_timestamp,
        body_text=queue_message.body_text,
        attachment_refs=queue_message.attachment_refs,
    )


def build_llm_context(queue_message: QueueMessage, extracted_attachments: list[dict[str, str]]) -> str:
    lines: list[str] = []
    thread_title = queue_message.thread_title or queue_message.subject
    lines.append(f"### Email thread title: {_safe_text(thread_title)}")
    lines.append("")

    thread_messages = queue_message.thread_messages or [_current_message_from_queue(queue_message)]
    for idx, message in enumerate(thread_messages, start=1):
        lines.append(f"#### Email message {idx}, Date: {_safe_text(message.received_timestamp)}")
        lines.append(f"From: {_safe_text(message.sender)}")
        lines.append(f"Subject: {_safe_text(message.subject)}")
        lines.append("Body:")
        lines.append(_safe_text(message.body_text))
        lines.append("")

    for idx, attachment in enumerate(extracted_attachments, start=1):
        lines.append(f"#### Email attachment {idx}")
        lines.append(f"Name: {_safe_text(attachment.get('name'))}")
        lines.append("Extracted text:")
        lines.append(_safe_text(attachment.get("text")))
        lines.append("")

    return "\n".join(lines).strip()
