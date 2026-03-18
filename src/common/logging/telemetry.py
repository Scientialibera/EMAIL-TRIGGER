from __future__ import annotations

import json
import logging
import time
from contextlib import contextmanager
from typing import Any


@contextmanager
def timed_step():
    """Context manager that measures wall-clock elapsed milliseconds."""
    start = time.perf_counter()
    result = {"elapsed_ms": 0}
    try:
        yield result
    finally:
        result["elapsed_ms"] = round((time.perf_counter() - start) * 1000)


def get_logger(name: str = "cqc_email_processor") -> logging.Logger:
    logger = logging.getLogger(name)
    if not logger.handlers:
        logger.setLevel(logging.INFO)
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
        logger.addHandler(handler)
    return logger


def log_event(
    logger: logging.Logger,
    event: str,
    correlation_id: str,
    level: int = logging.INFO,
    **fields: Any,
) -> None:
    payload = {"event": event, "correlation_id": correlation_id, **fields}
    logger.log(level, json.dumps(payload, default=str))
