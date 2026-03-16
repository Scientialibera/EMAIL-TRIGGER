from __future__ import annotations

import json
import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

from azure.storage.blob import BlobServiceClient
from src.common.auth.credentials import get_credential
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
    rejection_notice_logicapp_url: str
    processable_headers: list[str]
    request_info_header: str
    fabric_notebook_poll_seconds: int
    fabric_notebook_wait_timeout_seconds: int
    profile: ModelProfile
    extraction_schema: dict[str, Any]
    validity_prompt: str
    extraction_prompt: str
    rejection_subject_template: str
    rejection_body_template: str
    missing_info_subject_template: str
    missing_info_body_template: str


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
    storage_account = os.getenv("STORAGE_ACCOUNT_NAME", "")
    prompts_container = os.getenv("PROMPTS_CONTAINER_NAME", "")
    if storage_account and prompts_container:
        blob_name = os.getenv(f"{kind.upper()}_PROMPT_BLOB_NAME", f"{kind}/{name}.txt")
        account_url = f"https://{storage_account}.blob.core.windows.net"
        credential = get_credential()
        try:
            client = BlobServiceClient(account_url=account_url, credential=credential)
            blob = client.get_blob_client(container=prompts_container, blob=blob_name)
            return blob.download_blob().readall().decode("utf-8-sig")
        except Exception:
            # Fall back to local prompt files to preserve local dev ergonomics.
            pass

    prompt_path = _repo_root() / "src" / "prompts" / kind / f"{name}.txt"
    return _read_text(prompt_path)


def _require_non_empty(value: str, key: str) -> str:
    if not value:
        raise ValueError(f"Missing required configuration: {key}")
    return value


def _load_header_rules() -> dict[str, Any]:
    rules_path = _repo_root() / "src" / "config" / "email_header_rules.json"
    return json.loads(_read_text(rules_path))


def _load_email_templates() -> dict[str, Any]:
    templates_path = _repo_root() / "src" / "config" / "email_templates.json"
    return json.loads(_read_text(templates_path))


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
    templates = _load_email_templates()

    return AppSettings(
        servicebus_queue_name=os.getenv("SERVICEBUS_QUEUE_NAME", "q-cqc-email-process"),
        fabric_write_queue_name=os.getenv("FABRIC_WRITE_QUEUE_NAME", "q-cqc-fabric-write"),
        servicebus_namespace_fqdn=_require_non_empty(
            os.getenv("SERVICEBUS_NAMESPACE_FQDN", ""), "SERVICEBUS_NAMESPACE_FQDN"
        ),
        confidence_threshold_required=float(os.getenv("CONFIDENCE_THRESHOLD_REQUIRED", "0.97")),
        active_extraction_schema=active_schema,
        aoai_endpoint=_require_non_empty(os.getenv("AOAI_ENDPOINT", ""), "AOAI_ENDPOINT"),
        aoai_api_version=os.getenv("AOAI_API_VERSION", "2024-06-01"),
        docintel_endpoint=_require_non_empty(os.getenv("DOCINTEL_ENDPOINT", ""), "DOCINTEL_ENDPOINT"),
        fabric_notebook_job_endpoint=_require_non_empty(
            os.getenv("FABRIC_NOTEBOOK_JOB_ENDPOINT", ""), "FABRIC_NOTEBOOK_JOB_ENDPOINT"
        ),
        fabric_workspace_id=_require_non_empty(
            os.getenv("FABRIC_WORKSPACE_ID", ""), "FABRIC_WORKSPACE_ID"
        ),
        fabric_lakehouse_id=_require_non_empty(
            os.getenv("FABRIC_LAKEHOUSE_ID", ""), "FABRIC_LAKEHOUSE_ID"
        ),
        fabric_silver_table=os.getenv("FABRIC_SILVER_TABLE", "dbo.cqc_email_silver"),
        missing_info_logicapp_url=_require_non_empty(
            os.getenv("MISSING_INFO_LOGICAPP_URL", ""), "MISSING_INFO_LOGICAPP_URL"
        ),
        rejection_notice_logicapp_url=_require_non_empty(
            os.getenv("REJECTION_NOTICE_LOGICAPP_URL", ""), "REJECTION_NOTICE_LOGICAPP_URL"
        ),
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
        rejection_subject_template=templates.get(
            "rejection_subject_template", "Email rejected: {subject}"
        ),
        rejection_body_template=templates.get(
            "rejection_body_template",
            "Your email could not be processed automatically. Reason: {reason}. Thread: {thread_id}.",
        ),
        missing_info_subject_template=templates.get(
            "missing_info_subject_template", "Missing information required: {subject}"
        ),
        missing_info_body_template=templates.get(
            "missing_info_body_template",
            "Please provide the following missing fields: {missing_fields}. Thread: {thread_id}.",
        ),
    )
