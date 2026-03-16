from __future__ import annotations

from src.common.models.contracts import ExtractionRecord
from src.common.utils.fabric_command_builder import build_fabric_write_command
from src.processing_function.adapters.fabric_write_queue_client import FabricWriteQueueAdapter


def persist_record(
    record: ExtractionRecord,
    fabric_workspace_id: str,
    lakehouse_id: str,
    table_name: str,
    client: FabricWriteQueueAdapter,
) -> None:
    command = build_fabric_write_command(
        operation="process_email_cdc",
        thread_id=record.thread_id,
        correlation_id=record.correlation_id,
        fabric_workspace_id=fabric_workspace_id,
        lakehouse_id=lakehouse_id,
        table_name=table_name,
        payload={
            "record": record.model_dump(),
        },
    )
    client.enqueue(command)
