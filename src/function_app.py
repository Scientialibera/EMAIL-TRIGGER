from __future__ import annotations

import json
import logging

import azure.functions as func

from src.common.logging.telemetry import get_logger
from src.fabric_update_function.handler import apply_email_reply_update
from src.fabric_writer_function.handler import process_fabric_write_command
from src.processing_function.handler import process_email_message

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)
logger = get_logger()


@app.function_name(name="ProcessEmailMessage")
@app.service_bus_queue_trigger(
    arg_name="msg",
    queue_name="%SERVICEBUS_QUEUE_NAME%",
    connection="SERVICEBUS_CONNECTION",
)
def process_email_message_trigger(msg: func.ServiceBusMessage) -> None:
    process_email_message(msg.get_body(), logger)


@app.function_name(name="ApplyEmailReplyUpdate")
@app.route(route="apply-reply-update", methods=["POST"])
def apply_email_reply_update_trigger(req: func.HttpRequest) -> func.HttpResponse:
    try:
        payload = req.get_json()
        result = apply_email_reply_update(payload, logger)
        return func.HttpResponse(
            body=json.dumps({"status": "ok", "result": result}),
            status_code=200,
            mimetype="application/json",
        )
    except Exception as exc:  # pragma: no cover
        logging.exception("reply update failed: %s", exc)
        return func.HttpResponse(
            body=json.dumps({"status": "error", "error": str(exc)}),
            status_code=500,
            mimetype="application/json",
        )


@app.function_name(name="ProcessFabricWriteCommand")
@app.service_bus_queue_trigger(
    arg_name="msg",
    queue_name="%FABRIC_WRITE_QUEUE_NAME%",
    connection="SERVICEBUS_CONNECTION",
    is_sessions_enabled=True,
)
def process_fabric_write_command_trigger(msg: func.ServiceBusMessage) -> None:
    process_fabric_write_command(msg.get_body(), logger)
