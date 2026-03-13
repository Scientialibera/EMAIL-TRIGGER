from src.common.models.contracts import QueueMessage
from src.processing_function.pipeline.context_builder import build_llm_context


def test_build_llm_context_uses_thread_message_and_attachment_sections() -> None:
    queue_message = QueueMessage.model_validate(
        {
            "message_id": "m1",
            "internet_message_id": "im1",
            "thread_id": "t1",
            "subject": "COA Thread",
            "sender": "user@example.com",
            "received_timestamp": "2026-03-13T00:00:00Z",
            "prefilter_status": "processable",
            "correlation_id": "c1",
            "thread_messages": [
                {
                    "message_id": "m1",
                    "subject": "COA message",
                    "sender": "user@example.com",
                    "received_timestamp": "2026-03-13T00:00:00Z",
                    "body_text": "Please process attached COA.",
                }
            ],
        }
    )

    context = build_llm_context(
        queue_message,
        [{"name": "coa.pdf", "text": "Lead 0.2 ppm"}],
    )
    assert "### Email thread title:" in context
    assert "#### Email message 1, Date:" in context
    assert "#### Email attachment 1" in context
