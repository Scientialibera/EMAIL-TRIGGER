from __future__ import annotations

from src.common.models.fabric_commands import FabricWriteCommand


def build_fabric_write_command(
    *,
    operation: str,
    thread_id: str,
    correlation_id: str,
    fabric_workspace_id: str,
    lakehouse_id: str,
    table_name: str,
    payload: dict,
) -> FabricWriteCommand:
    base_payload = {
        "workspace_id": fabric_workspace_id,
        "lakehouse_id": lakehouse_id,
        "table": table_name,
    }
    base_payload.update(payload)
    return FabricWriteCommand(
        operation=operation,
        thread_id=thread_id,
        correlation_id=correlation_id,
        payload=base_payload,
    )
