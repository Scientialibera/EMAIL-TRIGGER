from __future__ import annotations

import json
import logging

from src.common.config.settings import get_settings
from src.common.logging.telemetry import log_event
from src.common.models.fabric_commands import FabricWriteCommand
from src.processing_function.adapters.fabric_client import FabricNotebookAdapter


def process_fabric_write_command(message_body: bytes, logger: logging.Logger) -> dict:
    settings = get_settings()
    payload = json.loads(message_body.decode("utf-8"))
    command = FabricWriteCommand.model_validate(payload)

    notebook_payload = {
        "executionData": {
            "operation": command.operation,
            **command.payload,
        }
    }

    fabric_client = FabricNotebookAdapter(
        notebook_job_endpoint=settings.fabric_notebook_job_endpoint,
        poll_seconds=settings.fabric_notebook_poll_seconds,
        wait_timeout_seconds=settings.fabric_notebook_wait_timeout_seconds,
    )
    result = fabric_client.run_notebook(notebook_payload)
    log_event(
        logger,
        "fabric_write_command_processed",
        command.correlation_id,
        thread_id=command.thread_id,
        operation=command.operation,
    )
    return result
