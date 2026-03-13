from __future__ import annotations

from src.common.models.contracts import QueueMessage


def is_processable(message: QueueMessage, processable_headers: list[str]) -> bool:
    if message.prefilter_status != "processable":
        return False
    if not processable_headers:
        return True
    header_name = (message.header_name or "").strip()
    return header_name in processable_headers
