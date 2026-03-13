from __future__ import annotations

from datetime import UTC, datetime

from src.common.models.contracts import ExtractionRecord
from src.processing_function.adapters.openai_client import AzureOpenAIAdapter


def extract_record(
    email_id: str,
    thread_id: str,
    receive_timestamp: str,
    attachment_names: list[str],
    text: str,
    image_data_urls: list[str],
    schema: dict,
    model_name: str,
    correlation_id: str,
    client: AzureOpenAIAdapter,
) -> ExtractionRecord:
    fields = client.extract_fields(text, schema, image_data_urls=image_data_urls)
    payload = {
        "email_id": email_id,
        "thread_id": thread_id,
        "attachment_names": attachment_names,
        "receive_timestamp": receive_timestamp,
        "status": "processed",
        "model_name": model_name,
        "model_version": schema.get("version", "v1"),
        "processed_at": datetime.now(UTC).isoformat(),
        "correlation_id": correlation_id,
    }
    payload.update(fields)
    return ExtractionRecord.model_validate(payload)
