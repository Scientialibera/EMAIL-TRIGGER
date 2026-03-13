from src.common.models.fabric_commands import FabricWriteCommand


def test_fabric_write_command_accepts_supported_operation() -> None:
    command = FabricWriteCommand.model_validate(
        {
            "operation": "process_email_cdc",
            "thread_id": "thread-1",
            "correlation_id": "corr-1",
            "payload": {"table": "dbo.cqc_email_silver"},
        }
    )
    assert command.thread_id == "thread-1"
