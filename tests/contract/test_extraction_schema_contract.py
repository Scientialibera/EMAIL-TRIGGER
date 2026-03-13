import json
from pathlib import Path


def test_schema_has_required_keys() -> None:
    path = Path("src/schemas/extraction/coa_v1.json")
    schema = json.loads(path.read_text(encoding="utf-8"))
    assert "required_fields" in schema
    assert "fields" in schema
    assert "output_contract" in schema
    for field_name in schema["required_fields"]:
        field_def = schema["fields"][field_name]
        assert field_def["type"] == "array"
        assert field_def["items"]["required"] == ["value", "confidence"]
