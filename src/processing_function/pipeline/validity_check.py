from __future__ import annotations

from src.processing_function.adapters.openai_client import AzureOpenAIAdapter


def evaluate_validity(text: str, client: AzureOpenAIAdapter) -> tuple[bool, str]:
    result = client.classify_validity(text)
    return bool(result.get("is_valid", False)), str(result.get("reason", "unknown"))
