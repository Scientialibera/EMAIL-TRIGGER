from datetime import UTC, datetime
import json
from typing import Any

from pyspark.sql import SparkSession
from pyspark.sql import functions as F


spark = SparkSession.builder.getOrCreate()


def _now_iso() -> str:
    return datetime.now(UTC).isoformat()


def _empty_if_none(payload: dict[str, Any] | None) -> dict[str, Any]:
    return payload if payload is not None else {}


def _set_previous_latest_false(table_name: str, thread_id: str) -> None:
    spark.sql(
        f"""
        UPDATE {table_name}
        SET latest_update = false
        WHERE thread_id = '{thread_id}' AND latest_update = true
        """
    )


def _append_row(table_name: str, row: dict[str, Any]) -> None:
    frame = spark.createDataFrame([row])
    frame.write.mode("append").saveAsTable(table_name)


def _merge_latest_payload(table_name: str, thread_id: str, email_id: str, updates: dict[str, Any]) -> dict[str, Any]:
    latest = (
        spark.table(table_name)
        .where((F.col("thread_id") == thread_id) & (F.col("latest_update") == True))
        .orderBy(F.col("last_modified").desc())
        .limit(1)
    )
    rows = latest.collect()
    if not rows:
        return updates
    current_payload = json.loads(rows[0]["record_json"]) if rows[0]["record_json"] else {}
    current_payload.update(updates)
    current_payload["thread_id"] = thread_id
    current_payload["email_id"] = email_id
    return current_payload


def _process_email_cdc(execution_data: dict[str, Any]) -> None:
    table_name = execution_data["table"]
    record = _empty_if_none(execution_data.get("record"))
    thread_id = record["thread_id"]
    email_id = record["email_id"]
    correlation_id = record.get("correlation_id", thread_id)

    _set_previous_latest_false(table_name, thread_id)

    new_row = {
        "thread_id": thread_id,
        "email_id": email_id,
        "status": record.get("status", "processed"),
        "record_json": json.dumps(record),
        "latest_update": True,
        "cdc_operation": "process_email_cdc",
        "updated_by_flow": "ProcessEmailMessage",
        "correlation_id": correlation_id,
        "created_at": _now_iso(),
        "last_modified": _now_iso(),
    }
    _append_row(table_name, new_row)


def _apply_reply_update_cdc(execution_data: dict[str, Any]) -> None:
    table_name = execution_data["table"]
    thread_id = execution_data["thread_id"]
    email_id = execution_data["email_id"]
    fields_to_update = _empty_if_none(execution_data.get("fields_to_update"))
    updated_by_flow = execution_data.get("updated_by_flow", "ApplyEmailReplyUpdate")
    correlation_id = execution_data.get("correlation_id", thread_id)

    _set_previous_latest_false(table_name, thread_id)
    merged_payload = _merge_latest_payload(table_name, thread_id, email_id, fields_to_update)
    merged_payload["status"] = "updated"

    new_row = {
        "thread_id": thread_id,
        "email_id": email_id,
        "status": "updated",
        "record_json": json.dumps(merged_payload),
        "latest_update": True,
        "cdc_operation": "apply_reply_update_cdc",
        "updated_by_flow": updated_by_flow,
        "correlation_id": correlation_id,
        "created_at": _now_iso(),
        "last_modified": _now_iso(),
    }
    _append_row(table_name, new_row)


def main(executionData: dict[str, Any]) -> dict[str, Any]:
    operation = executionData.get("operation", "")
    if operation == "process_email_cdc":
        _process_email_cdc(executionData)
        return {"status": "ok", "operation": operation}
    if operation == "apply_reply_update_cdc":
        _apply_reply_update_cdc(executionData)
        return {"status": "ok", "operation": operation}
    raise ValueError(f"Unsupported operation: {operation}")
