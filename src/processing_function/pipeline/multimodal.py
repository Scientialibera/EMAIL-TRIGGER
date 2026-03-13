from __future__ import annotations

from src.common.models.contracts import QueueMessage


def _as_data_url(image_base64: str) -> str:
    return f"data:image/png;base64,{image_base64}"


def collect_image_data_urls(
    queue_message: QueueMessage, extracted_attachments: list[dict[str, object]]
) -> list[str]:
    image_urls: list[str] = []

    for inline_image in queue_message.inline_images_base64:
        if inline_image:
            image_urls.append(_as_data_url(inline_image))
    for message in queue_message.thread_messages:
        for inline_image in message.inline_images_base64:
            if inline_image:
                image_urls.append(_as_data_url(inline_image))

    for attachment in extracted_attachments:
        for preview_image in attachment.get("preview_images_base64", []):
            if isinstance(preview_image, str) and preview_image:
                image_urls.append(_as_data_url(preview_image))

    # Deduplicate while preserving order.
    seen: set[str] = set()
    ordered_unique: list[str] = []
    for url in image_urls:
        if url in seen:
            continue
        seen.add(url)
        ordered_unique.append(url)
    return ordered_unique
