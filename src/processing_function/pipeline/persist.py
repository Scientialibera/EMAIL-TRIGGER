from __future__ import annotations

from src.common.models.fabric_commands import FabricWriteCommand
from src.common.models.contracts import ExtractionRecord
from src.processing_function.adapters.fabric_write_queue_client import FabricWriteQueueAdapter


def persist_record(
    record: ExtractionRecord,
    fabric_workspace_id: str,
    lakehouse_id: str,
    table_name: str,
    client: FabricWriteQueueAdapter,
) -> None:
    command = FabricWriteCommand(
        operation="process_email_cdc",
        thread_id=record.thread_id,
        correlation_id=record.correlation_id,
        payload={
            "workspace_id": fabric_workspace_id,
            "lakehouse_id": lakehouse_id,
            "table": table_name,
            "record": record.model_dump(),
        },
    )
    client.enqueue(command)
