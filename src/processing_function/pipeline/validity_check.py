from __future__ import annotations

from src.processing_function.adapters.openai_client import AzureOpenAIAdapter


def evaluate_validity(
    text: str, image_data_urls: list[str], client: AzureOpenAIAdapter
) -> tuple[bool, str]:
    result = client.classify_validity(text, image_data_urls=image_data_urls)
    return bool(result.get("approved", False)), str(result.get("reason", "unknown"))
