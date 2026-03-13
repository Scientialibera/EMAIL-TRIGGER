from __future__ import annotations

from src.common.models.contracts import QueueMessage


def is_processable(message: QueueMessage) -> bool:
    return message.prefilter_status == "processable"
