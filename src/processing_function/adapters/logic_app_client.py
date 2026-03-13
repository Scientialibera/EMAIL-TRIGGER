from __future__ import annotations

import requests


class LogicAppAdapter:
    def __init__(self, invoke_url: str) -> None:
        self._invoke_url = invoke_url

    def send_missing_info_request(self, payload: dict) -> None:
        if not self._invoke_url:
            return
        response = requests.post(self._invoke_url, json=payload, timeout=30)
        response.raise_for_status()
