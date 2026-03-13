from __future__ import annotations

import json
from typing import Any

import requests

from src.common.auth.credentials import get_access_token
from src.common.config.settings import AppSettings
from src.common.utils.retry import retry


class AzureOpenAIAdapter:
    AOAI_SCOPE = "https://cognitiveservices.azure.com/.default"

    def __init__(self, settings: AppSettings) -> None:
        self._settings = settings

    def _chat_completion(self, deployment: str, prompt: str, content: str) -> dict[str, Any]:
        url = (
            f"{self._settings.aoai_endpoint}/openai/deployments/{deployment}/chat/completions"
            f"?api-version={self._settings.aoai_api_version}"
        )
        token = get_access_token(self.AOAI_SCOPE)
        body = {
            "temperature": self._settings.profile.temperature,
            "max_tokens": self._settings.profile.max_tokens,
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": content},
            ],
            "response_format": {"type": "json_object"},
        }
        def _request() -> dict[str, Any]:
            response = requests.post(
                url, json=body, headers={"Authorization": f"Bearer {token}"}, timeout=60
            )
            response.raise_for_status()
            return response.json()

        payload = retry(_request, retries=3)
        text = payload["choices"][0]["message"]["content"]
        return json.loads(text)

    def classify_validity(self, text: str) -> dict[str, Any]:
        return self._chat_completion(
            deployment=self._settings.profile.validity_model,
            prompt=self._settings.validity_prompt,
            content=text,
        )

    def extract_fields(self, text: str, schema: dict[str, Any]) -> dict[str, Any]:
        extraction_input = f"schema:\n{json.dumps(schema)}\n\ntext:\n{text}"
        return self._chat_completion(
            deployment=self._settings.profile.extraction_model,
            prompt=self._settings.extraction_prompt,
            content=extraction_input,
        )
