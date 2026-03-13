from __future__ import annotations

import time
from typing import Any

import requests

from src.common.auth.credentials import get_access_token
from src.common.utils.retry import retry


class FabricNotebookAdapter:
    FABRIC_SCOPE = "https://api.fabric.microsoft.com/.default"
    RUNNING_STATES = {"NotStarted", "Queued", "InProgress", "Running"}

    def __init__(
        self,
        notebook_job_endpoint: str,
        poll_seconds: int = 10,
        wait_timeout_seconds: int = 1800,
    ) -> None:
        self._endpoint = notebook_job_endpoint
        self._poll_seconds = poll_seconds
        self._wait_timeout_seconds = wait_timeout_seconds

    def _jobs_endpoint(self) -> str:
        return self._endpoint.split("?", 1)[0]

    def _auth_headers(self) -> dict[str, str]:
        token = get_access_token(self.FABRIC_SCOPE)
        return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    def _list_job_instances(self) -> list[dict[str, Any]]:
        response = requests.get(self._jobs_endpoint(), headers=self._auth_headers(), timeout=30)
        response.raise_for_status()
        payload = response.json() if response.text else {}
        if isinstance(payload, dict) and isinstance(payload.get("value"), list):
            return payload["value"]
        if isinstance(payload, list):
            return payload
        return []

    def _has_running_notebook_job(self) -> bool:
        for job in self._list_job_instances():
            state = str(job.get("status") or job.get("state") or "").strip()
            if state in self.RUNNING_STATES:
                return True
        return False

    def wait_until_notebook_idle(self) -> None:
        start = time.time()
        while self._has_running_notebook_job():
            elapsed = time.time() - start
            if elapsed > self._wait_timeout_seconds:
                raise TimeoutError("Timed out waiting for running Fabric notebook jobs to finish.")
            time.sleep(self._poll_seconds)

    def run_notebook(self, payload: dict[str, Any]) -> dict[str, Any]:
        self.wait_until_notebook_idle()

        def _request() -> dict[str, Any]:
            response = requests.post(
                self._endpoint,
                json=payload,
                headers=self._auth_headers(),
                timeout=60,
            )
            response.raise_for_status()
            return response.json() if response.text else {}

        return retry(_request, retries=3)
