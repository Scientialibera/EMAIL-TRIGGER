from __future__ import annotations

import base64

from src.common.models.contracts import AttachmentRef
from src.processing_function.adapters.doc_intelligence_client import DocumentIntelligenceAdapter


def convert_attachments_to_text(
    attachments: list[AttachmentRef], doc_client: DocumentIntelligenceAdapter
) -> tuple[list[dict[str, object]], list[str], list[bytes]]:
    extracted_attachments: list[dict[str, object]] = []
    names: list[str] = []
    content_bytes: list[bytes] = []

    for attachment in attachments:
        if not attachment.content_base64:
            continue
        raw = base64.b64decode(attachment.content_base64)
        extracted = doc_client.extract_text(raw)
        preview_images = list(attachment.preview_images_base64)
        if attachment.content_type.startswith("image/"):
            preview_images.append(attachment.content_base64)
        extracted_attachments.append(
            {"name": attachment.name, "text": extracted, "preview_images_base64": preview_images}
        )
        names.append(attachment.name)
        content_bytes.append(raw)

    return extracted_attachments, names, content_bytes
