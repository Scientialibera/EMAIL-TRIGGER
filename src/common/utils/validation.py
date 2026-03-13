from __future__ import annotations

from src.common.models.contracts import ExtractionRecord


def compute_missing_fields(record: ExtractionRecord, required_fields: list[str], threshold: float) -> list[str]:
    missing: list[str] = []
    data = record.model_dump()
    for field_name in required_fields:
        value = data.get(field_name)
        if value is None or not isinstance(value, list) or len(value) == 0:
            missing.append(field_name)
            continue
        has_valid_item = any(
            isinstance(item, dict)
            and item.get("value") not in (None, "", [])
            and float(item.get("confidence", 0.0)) >= threshold
            for item in value
        )
        if not has_valid_item:
            missing.append(field_name)
    return missing


def sanitize_updates(fields: dict[str, object], allowed_fields: set[str]) -> dict[str, object]:
    return {k: v for k, v in fields.items() if k in allowed_fields and v not in ("", None)}
