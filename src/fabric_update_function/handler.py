from __future__ import annotations

import logging

from src.common.config.settings import get_settings
from src.common.logging.telemetry import log_event
from src.fabric_update_function.adapters.fabric_client import FabricNotebookAdapter
from src.fabric_update_function.updater.apply_update import apply_update
from src.fabric_update_function.updater.parse_reply import parse_reply_payload


def apply_email_reply_update(payload: dict, logger: logging.Logger) -> dict:
    settings = get_settings()
    correlation_id = payload.get("correlation_id", payload.get("thread_id", "unknown"))
    allowed_fields = set(settings.extraction_schema.get("fields", {}).keys())

    update_payload = parse_reply_payload(payload, allowed_fields)
    fabric_client = FabricNotebookAdapter(settings.fabric_notebook_job_endpoint)
    result = apply_update(
        payload=update_payload,
        fabric_workspace_id=settings.fabric_workspace_id,
        lakehouse_id=settings.fabric_lakehouse_id,
        table_name=settings.fabric_silver_table,
        client=fabric_client,
    )
    log_event(
        logger,
        "reply_update_applied",
        correlation_id,
        email_id=update_payload.email_id,
        updated_fields=list(update_payload.fields_to_update.keys()),
    )
    return result
