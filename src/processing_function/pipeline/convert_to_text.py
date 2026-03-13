from __future__ import annotations

import base64

from src.common.models.contracts import AttachmentRef
from src.processing_function.adapters.doc_intelligence_client import DocumentIntelligenceAdapter


def convert_attachments_to_text(
    attachments: list[AttachmentRef], doc_client: DocumentIntelligenceAdapter
) -> tuple[list[dict[str, str]], list[str], list[bytes]]:
    extracted_attachments: list[dict[str, str]] = []
    names: list[str] = []
    content_bytes: list[bytes] = []

    for attachment in attachments:
        if not attachment.content_base64:
            continue
        raw = base64.b64decode(attachment.content_base64)
        extracted = doc_client.extract_text(raw)
        extracted_attachments.append({"name": attachment.name, "text": extracted})
        names.append(attachment.name)
        content_bytes.append(raw)

    return extracted_attachments, names, content_bytes
