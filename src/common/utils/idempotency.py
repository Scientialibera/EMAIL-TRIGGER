from __future__ import annotations

import hashlib


def compute_attachment_hash(attachment_bytes: bytes) -> str:
    return hashlib.sha256(attachment_bytes).hexdigest()


def build_idempotency_key(internet_message_id: str, attachment_hashes: list[str]) -> str:
    base = f"{internet_message_id}|{'|'.join(sorted(attachment_hashes))}"
    return hashlib.sha256(base.encode("utf-8")).hexdigest()
