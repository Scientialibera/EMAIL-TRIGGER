from src.common.models.contracts import ExtractionRecord
from src.common.utils.validation import compute_missing_fields


def test_compute_missing_fields_uses_threshold() -> None:
    record = ExtractionRecord.model_validate(
        {
            "email_id": "id1",
            "thread_id": "t1",
            "attachment_names": [],
            "receive_timestamp": "2026-03-13T00:00:00Z",
            "supplier_name": [{"value": "Acme", "confidence": 0.9}],
            "status": "processed",
            "model_name": "gpt",
            "model_version": "1",
            "processed_at": "2026-03-13T00:00:00Z",
            "correlation_id": "c1",
        }
    )

    missing = compute_missing_fields(record, ["supplier_name"], 0.97)
    assert missing == ["supplier_name"]
