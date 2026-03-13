from __future__ import annotations

from typing import Any

import requests

from src.common.auth.credentials import get_access_token
from src.common.utils.retry import retry


class FabricNotebookAdapter:
    FABRIC_SCOPE = "https://api.fabric.microsoft.com/.default"

    def __init__(self, notebook_job_endpoint: str) -> None:
        self._endpoint = notebook_job_endpoint

    def run_notebook(self, payload: dict[str, Any]) -> dict[str, Any]:
        token = get_access_token(self.FABRIC_SCOPE)
        def _request() -> dict[str, Any]:
            response = requests.post(
                self._endpoint,
                json=payload,
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                timeout=60,
            )
            response.raise_for_status()
            return response.json() if response.text else {}

        return retry(_request, retries=3)
