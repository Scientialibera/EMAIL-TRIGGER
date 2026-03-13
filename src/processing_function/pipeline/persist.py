from __future__ import annotations

from src.common.models.contracts import ExtractionRecord
from src.processing_function.adapters.fabric_client import FabricNotebookAdapter


def persist_record(
    record: ExtractionRecord, fabric_workspace_id: str, lakehouse_id: str, table_name: str, client: FabricNotebookAdapter
) -> dict:
    payload = {
        "executionData": {
            "operation": "upsert_silver_record",
            "workspace_id": fabric_workspace_id,
            "lakehouse_id": lakehouse_id,
            "table": table_name,
            "record": record.model_dump(),
        }
    }
    return client.run_notebook(payload)
