from __future__ import annotations

from datetime import UTC, datetime

from src.common.models.contracts import ReplyUpdatePayload
from src.common.utils.fabric_command_builder import build_fabric_write_command
from src.processing_function.adapters.fabric_write_queue_client import FabricWriteQueueAdapter


def apply_update(
    payload: ReplyUpdatePayload,
    fabric_workspace_id: str,
    lakehouse_id: str,
    table_name: str,
    client: FabricWriteQueueAdapter,
) -> None:
    command = build_fabric_write_command(
        operation="apply_reply_update_cdc",
        thread_id=payload.thread_id,
        correlation_id=payload.correlation_id,
        fabric_workspace_id=fabric_workspace_id,
        lakehouse_id=lakehouse_id,
        table_name=table_name,
        payload={
            "email_id": payload.email_id,
            "thread_id": payload.thread_id,
            "fields_to_update": payload.fields_to_update,
            "status": "updated",
            "updated_by_flow": payload.updated_by_flow,
            "correlation_id": payload.correlation_id,
            "updated_at": datetime.now(UTC).isoformat(),
        },
    )
    client.enqueue(command)
