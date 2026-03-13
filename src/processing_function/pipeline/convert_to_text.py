from __future__ import annotations

import base64

from src.common.models.contracts import AttachmentRef
from src.processing_function.adapters.doc_intelligence_client import DocumentIntelligenceAdapter


def convert_attachments_to_text(
    attachments: list[AttachmentRef], doc_client: DocumentIntelligenceAdapter
) -> tuple[str, list[str], list[bytes]]:
    chunks: list[str] = []
    names: list[str] = []
    content_bytes: list[bytes] = []

    for attachment in attachments:
        if not attachment.content_base64:
            continue
        raw = base64.b64decode(attachment.content_base64)
        extracted = doc_client.extract_text(raw)
        chunks.append(f"Attachment: {attachment.name}\n{extracted}")
        names.append(attachment.name)
        content_bytes.append(raw)

    return "\n\n".join(chunks), names, content_bytes
