from __future__ import annotations

import json
import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml


@dataclass(frozen=True)
class ModelProfile:
    validity_model: str
    extraction_model: str
    temperature: float
    max_tokens: int
    profile_name: str


@dataclass(frozen=True)
class AppSettings:
    servicebus_queue_name: str
    fabric_write_queue_name: str
    servicebus_namespace_fqdn: str
    confidence_threshold_required: float
    active_extraction_schema: str
    aoai_endpoint: str
    aoai_api_version: str
    docintel_endpoint: str
    fabric_notebook_job_endpoint: str
    fabric_workspace_id: str
    fabric_lakehouse_id: str
    fabric_silver_table: str
    missing_info_logicapp_url: str
    processable_headers: list[str]
    request_info_header: str
    fabric_notebook_poll_seconds: int
    fabric_notebook_wait_timeout_seconds: int
    profile: ModelProfile
    extraction_schema: dict[str, Any]
    validity_prompt: str
    extraction_prompt: str


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _load_profile(profile_name: str) -> ModelProfile:
    profile_path = _repo_root() / "src" / "model_profiles" / f"{profile_name}.yaml"
    payload = yaml.safe_load(_read_text(profile_path))
    return ModelProfile(
        validity_model=_resolve_env_placeholder(payload["validity_model"]),
        extraction_model=_resolve_env_placeholder(payload["extraction_model"]),
        temperature=float(payload.get("temperature", 0.0)),
        max_tokens=int(payload.get("max_tokens", 2000)),
        profile_name=profile_name,
    )


def _load_schema(schema_name: str) -> dict[str, Any]:
    schema_path = _repo_root() / "src" / "schemas" / "extraction" / f"{schema_name}.json"
    return json.loads(_read_text(schema_path))


def _load_prompt(kind: str, name: str) -> str:
    prompt_path = _repo_root() / "src" / "prompts" / kind / f"{name}.txt"
    return _read_text(prompt_path)


def _load_header_rules() -> dict[str, Any]:
    rules_path = _repo_root() / "src" / "config" / "email_header_rules.json"
    return json.loads(_read_text(rules_path))


def _resolve_env_placeholder(value: str) -> str:
    if value.startswith("${") and value.endswith("}"):
        env_key = value[2:-1]
        return os.getenv(env_key, "")
    return value


@lru_cache(maxsize=1)
def get_settings() -> AppSettings:
    active_profile = os.getenv("ACTIVE_MODEL_PROFILE", "default")
    active_schema = os.getenv("ACTIVE_EXTRACTION_SCHEMA", "coa_v1")

    profile = _load_profile(active_profile)
    schema = _load_schema(active_schema)
    header_rules = _load_header_rules()

    return AppSettings(
        servicebus_queue_name=os.getenv("SERVICEBUS_QUEUE_NAME", "q-cqc-email-process"),
        fabric_write_queue_name=os.getenv("FABRIC_WRITE_QUEUE_NAME", "q-cqc-fabric-write"),
        servicebus_namespace_fqdn=os.getenv("SERVICEBUS_NAMESPACE_FQDN", ""),
        confidence_threshold_required=float(os.getenv("CONFIDENCE_THRESHOLD_REQUIRED", "0.97")),
        active_extraction_schema=active_schema,
        aoai_endpoint=os.getenv("AOAI_ENDPOINT", ""),
        aoai_api_version=os.getenv("AOAI_API_VERSION", "2024-06-01"),
        docintel_endpoint=os.getenv("DOCINTEL_ENDPOINT", ""),
        fabric_notebook_job_endpoint=os.getenv("FABRIC_NOTEBOOK_JOB_ENDPOINT", ""),
        fabric_workspace_id=os.getenv("FABRIC_WORKSPACE_ID", ""),
        fabric_lakehouse_id=os.getenv("FABRIC_LAKEHOUSE_ID", ""),
        fabric_silver_table=os.getenv("FABRIC_SILVER_TABLE", "dbo.cqc_email_silver"),
        missing_info_logicapp_url=os.getenv("MISSING_INFO_LOGICAPP_URL", ""),
        processable_headers=header_rules.get("processable_headers", []),
        request_info_header=header_rules.get("request_info_header", "CQC-REQUEST-INFO"),
        fabric_notebook_poll_seconds=int(os.getenv("FABRIC_NOTEBOOK_POLL_SECONDS", "10")),
        fabric_notebook_wait_timeout_seconds=int(
            os.getenv("FABRIC_NOTEBOOK_WAIT_TIMEOUT_SECONDS", "1800")
        ),
        profile=profile,
        extraction_schema=schema,
        validity_prompt=_load_prompt("validity", "validity_v1"),
        extraction_prompt=_load_prompt("extraction", "extraction_v1"),
    )
