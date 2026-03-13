from __future__ import annotations

from azure.ai.formrecognizer import DocumentAnalysisClient

from src.common.auth.credentials import get_credential
from src.common.utils.retry import retry


class DocumentIntelligenceAdapter:
    def __init__(self, endpoint: str) -> None:
        self._client = DocumentAnalysisClient(endpoint=endpoint, credential=get_credential())

    def extract_text(self, file_bytes: bytes) -> str:
        def _analyze():
            poller = self._client.begin_analyze_document("prebuilt-read", document=file_bytes)
            return poller.result()

        result = retry(_analyze, retries=3)
        lines: list[str] = []
        for page in result.pages:
            for line in page.lines:
                lines.append(line.content)
        return "\n".join(lines)
