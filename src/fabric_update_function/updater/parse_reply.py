from __future__ import annotations

from src.common.models.contracts import ReplyUpdatePayload
from src.common.utils.validation import sanitize_updates


def parse_reply_payload(payload: dict, allowed_fields: set[str]) -> ReplyUpdatePayload:
    cleaned = sanitize_updates(payload.get("fields_to_update", {}), allowed_fields)
    return ReplyUpdatePayload(
        email_id=payload["email_id"],
        thread_id=payload["thread_id"],
        correlation_id=payload.get("correlation_id", payload["thread_id"]),
        fields_to_update=cleaned,
    )
