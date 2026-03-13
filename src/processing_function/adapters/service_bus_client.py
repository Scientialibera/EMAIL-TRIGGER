from __future__ import annotations

import json

from src.common.models.contracts import QueueMessage


def parse_service_bus_message(body: bytes) -> QueueMessage:
    payload = json.loads(body.decode("utf-8"))
    return QueueMessage.model_validate(payload)
