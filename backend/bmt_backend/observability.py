"""Small structured logger with an explicit field allowlist and no request bodies."""

import json
import logging


class JsonFormatter(logging.Formatter):
    def format(self, record):
        message = record.getMessage()
        try:
            value = json.loads(message)
        except ValueError:
            value = {"event": message}
        if not isinstance(value, dict):
            value = {"event": message}
        value["level"] = record.levelname.lower()
        for field in ("run_id", "time_ticks", "failure_code", "worker_id",
                      "verification_seconds", "verification_compute_ms", "verification_method", "queue_wait_seconds", "shutdown_seconds", "stop_signal"):
            if hasattr(record, field):
                value[field] = getattr(record, field)
        # Record only exception type: arbitrary exception text can include submitted data.
        if record.exc_info:
            value["exception_type"] = record.exc_info[0].__name__
        return json.dumps(value, separators=(",", ":"))


def configure_logging():
    logger = logging.getLogger("bmt")
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False
