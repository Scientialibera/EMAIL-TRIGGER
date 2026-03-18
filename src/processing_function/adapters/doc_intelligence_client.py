from __future__ import annotations

import json
import logging

from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.ai.documentintelligence.models import AnalyzeDocumentRequest

from src.common.auth.credentials import get_credential
from src.common.logging.telemetry import timed_step
from src.common.utils.retry import retry

_logger = logging.getLogger(__name__)


class DocumentIntelligenceAdapter:
    def __init__(self, endpoint: str) -> None:
        self._client = DocumentIntelligenceClient(endpoint=endpoint, credential=get_credential())

    def extract_text(self, file_bytes: bytes) -> str:
        with timed_step() as t:
            def _analyze():
                poller = self._client.begin_analyze_document(
                    "prebuilt-read",
                    AnalyzeDocumentRequest(bytes_source=file_bytes),
                )
                return poller.result()

            result = retry(_analyze, retries=3)

        pages = result.pages or []
        lines: list[str] = []
        for page in pages:
            for line in page.lines or []:
                lines.append(line.content)

        _logger.info(json.dumps({
            "event": "doc_intelligence_call",
            "elapsed_ms": t["elapsed_ms"],
            "pages": len(pages),
            "input_bytes": len(file_bytes),
        }, default=str))

        return "\n".join(lines)
