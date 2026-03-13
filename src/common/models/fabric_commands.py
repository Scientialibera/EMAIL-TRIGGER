from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel


class FabricWriteCommand(BaseModel):
    operation: Literal["process_email_cdc", "apply_reply_update_cdc"]
    thread_id: str
    correlation_id: str
    payload: dict[str, Any]
