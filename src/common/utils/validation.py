from __future__ import annotations

from src.common.models.contracts import ExtractionRecord


def compute_missing_fields(record: ExtractionRecord, required_fields: list[str], threshold: float) -> list[str]:
    missing: list[str] = []
    data = record.model_dump()
    for field_name in required_fields:
        value = data.get(field_name)
        if value is None:
            missing.append(field_name)
            continue
        confidence = value.get("confidence", 0.0)
        if value.get("value") in (None, "", []) or confidence < threshold:
            missing.append(field_name)
    return missing


def sanitize_updates(fields: dict[str, object], allowed_fields: set[str]) -> dict[str, object]:
    return {k: v for k, v in fields.items() if k in allowed_fields and v not in ("", None)}
