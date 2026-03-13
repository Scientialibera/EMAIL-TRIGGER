from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class AttachmentRef(BaseModel):
    name: str
    content_type: str
    size_bytes: int = 0
    content_base64: str | None = None


class QueueMessage(BaseModel):
    message_id: str
    internet_message_id: str
    thread_id: str
    subject: str
    sender: str
    received_timestamp: str
    attachment_refs: list[AttachmentRef] = Field(default_factory=list)
    prefilter_status: Literal["processable", "rejected"]
    correlation_id: str


class ExtractedField(BaseModel):
    value: Any
    confidence: float


class ExtractionRecord(BaseModel):
    email_id: str
    thread_id: str
    attachment_names: list[str]
    receive_timestamp: str
    product_type: list[ExtractedField] | None = None
    supplier_name: list[ExtractedField] | None = None
    lot_number: list[ExtractedField] | None = None
    coa_date: list[ExtractedField] | None = None
    lead: list[ExtractedField] | None = None
    cadmium: list[ExtractedField] | None = None
    moisture_percentage: list[ExtractedField] | None = None
    missing_fields: list[str] = Field(default_factory=list)
    status: Literal["processed", "missing_info", "rejected", "updated"]
    model_name: str
    model_version: str
    processed_at: str
    correlation_id: str


class ReplyUpdatePayload(BaseModel):
    email_id: str
    thread_id: str
    correlation_id: str
    fields_to_update: dict[str, Any]
    updated_by_flow: str = "ApplyEmailReplyUpdate"
