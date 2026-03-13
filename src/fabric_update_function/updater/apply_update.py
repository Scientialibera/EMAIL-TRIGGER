from __future__ import annotations

from datetime import UTC, datetime

from src.common.models.contracts import ReplyUpdatePayload
from src.fabric_update_function.adapters.fabric_client import FabricNotebookAdapter


def apply_update(
    payload: ReplyUpdatePayload,
    fabric_workspace_id: str,
    lakehouse_id: str,
    table_name: str,
    client: FabricNotebookAdapter,
) -> dict:
    notebook_payload = {
        "executionData": {
            "operation": "apply_reply_update",
            "workspace_id": fabric_workspace_id,
            "lakehouse_id": lakehouse_id,
            "table": table_name,
            "email_id": payload.email_id,
            "thread_id": payload.thread_id,
            "fields_to_update": payload.fields_to_update,
            "status": "updated",
            "updated_by_flow": payload.updated_by_flow,
            "updated_at": datetime.now(UTC).isoformat(),
        }
    }
    return client.run_notebook(notebook_payload)
