from src.common.models.contracts import QueueMessage
from src.processing_function.pipeline.prefilter import is_processable


def test_prefilter_requires_matching_configured_header() -> None:
    message = QueueMessage.model_validate(
        {
            "message_id": "m1",
            "internet_message_id": "i1",
            "thread_id": "t1",
            "subject": "COA incoming",
            "sender": "user@example.com",
            "received_timestamp": "2026-03-13T00:00:00Z",
            "attachment_refs": [],
            "prefilter_status": "processable",
            "correlation_id": "c1",
            "header_name": "CQC-PROCESSABLE",
        }
    )
    assert is_processable(message, ["CQC-PROCESSABLE"])
