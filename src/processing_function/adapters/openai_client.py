from __future__ import annotations

import json
import logging
from typing import Any

import requests

from src.common.auth.credentials import get_access_token
from src.common.config.settings import AppSettings
from src.common.logging.telemetry import timed_step
from src.common.utils.retry import retry

_logger = logging.getLogger(__name__)


class AzureOpenAIAdapter:
    AOAI_SCOPE = "https://cognitiveservices.azure.com/.default"

    def __init__(self, settings: AppSettings) -> None:
        self._settings = settings

    def _chat_completion(
        self,
        deployment: str,
        prompt: str,
        content: str,
        image_data_urls: list[str] | None = None,
        tools: list[dict[str, Any]] | None = None,
        tool_choice: dict[str, Any] | str | None = None,
    ) -> dict[str, Any]:
        url = (
            f"{self._settings.aoai_endpoint}/openai/deployments/{deployment}/chat/completions"
            f"?api-version={self._settings.aoai_api_version}"
        )
        token = get_access_token(self.AOAI_SCOPE)
        user_content: list[dict[str, Any]] = [{"type": "text", "text": content}]
        for image_data_url in image_data_urls or []:
            user_content.append({"type": "image_url", "image_url": {"url": image_data_url}})

        body: dict[str, Any] = {
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": user_content},
            ],
        }
        if self._settings.profile.reasoning_model:
            body["reasoning_effort"] = self._settings.profile.reasoning_effort
        else:
            if self._settings.profile.temperature is not None:
                body["temperature"] = self._settings.profile.temperature
            if self._settings.profile.max_completion_tokens:
                body["max_completion_tokens"] = self._settings.profile.max_completion_tokens
        if tools:
            body["tools"] = tools
            if tool_choice:
                body["tool_choice"] = tool_choice
        else:
            body["response_format"] = {"type": "json_object"}

        with timed_step() as t:
            def _request() -> dict[str, Any]:
                response = requests.post(
                    url, json=body, headers={"Authorization": f"Bearer {token}"}, timeout=60
                )
                response.raise_for_status()
                return response.json()

            payload = retry(_request, retries=3)

        usage = payload.get("usage", {})
        _logger.info(json.dumps({
            "event": "openai_api_call",
            "deployment": deployment,
            "elapsed_ms": t["elapsed_ms"],
            "prompt_tokens": usage.get("prompt_tokens"),
            "completion_tokens": usage.get("completion_tokens"),
            "total_tokens": usage.get("total_tokens"),
        }, default=str))

        message = payload["choices"][0]["message"]
        if message.get("tool_calls"):
            return json.loads(message["tool_calls"][0]["function"]["arguments"])
        text = message.get("content", "{}")
        return json.loads(text if isinstance(text, str) else "{}")

    def classify_validity(self, text: str, image_data_urls: list[str] | None = None) -> dict[str, Any]:
        approval_tool = {
            "type": "function",
            "function": {
                "name": "set_approval_status",
                "description": "Sets whether the email should proceed to extraction.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "approved": {"type": "boolean"},
                        "reason": {"type": "string"},
                    },
                    "required": ["approved", "reason"],
                    "additionalProperties": False,
                },
            },
        }
        return self._chat_completion(
            deployment=self._settings.profile.validity_model,
            prompt=self._settings.validity_prompt,
            content=text,
            image_data_urls=image_data_urls,
            tools=[approval_tool],
            tool_choice={"type": "function", "function": {"name": "set_approval_status"}},
        )

    def extract_fields(
        self, text: str, schema: dict[str, Any], image_data_urls: list[str] | None = None
    ) -> dict[str, Any]:
        extraction_input = f"schema:\n{json.dumps(schema)}\n\ntext:\n{text}"
        return self._chat_completion(
            deployment=self._settings.profile.extraction_model,
            prompt=self._settings.extraction_prompt,
            content=extraction_input,
            image_data_urls=image_data_urls,
        )
