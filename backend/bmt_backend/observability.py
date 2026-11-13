"""Small structured logger with an explicit field allowlist and no request bodies."""

import json
import logging
import re


def failure_site(error=None, traceback=None):
    """Deepest first-party source location, without paths, locals or error text."""
    current = traceback if traceback is not None else getattr(error, "__traceback__", None)
    site = "external"
    while current is not None:
        frame = current.tb_frame
        module = frame.f_globals.get("__name__", "")
        function = frame.f_code.co_name
        if isinstance(module, str) and re.fullmatch(r"bmt_backend(?:\.[A-Za-z_][A-Za-z_0-9]*)+", module) and re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", function):
            site = f"{module}:{function}:{current.tb_lineno}"
        current = current.tb_next
    return site


def dependency_failure(logger, error, request_id, dependency):
    fields = {"request_id": request_id, "exception_type": type(error).__name__, "failure_site": failure_site(error)}
    sqlstate = getattr(getattr(error, "orig", None), "sqlstate", None)
    if isinstance(sqlstate, str) and re.fullmatch(r"[A-Z0-9]{5}", sqlstate):
        fields["sqlstate"] = sqlstate
    logger.error(dependency + "_unavailable", extra=fields)


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
        for field in ("run_id", "time_ticks", "failure_code", "worker_id", "request_id", "exception_type", "sqlstate",
                      "verification_seconds", "verification_compute_ms", "verification_method", "queue_wait_seconds", "shutdown_seconds", "stop_signal",
                      "generation_id", "generation_seconds", "telemetry_stage", "telemetry_owners"):
            if hasattr(record, field):
                value[field] = getattr(record, field)
        # Record only exception type: arbitrary exception text can include submitted data.
        if record.exc_info and record.exc_info[0] is not None:
            value["exception_type"] = record.exc_info[0].__name__
            value["failure_site"] = failure_site(traceback=record.exc_info[2])
        elif hasattr(record, "failure_site") and re.fullmatch(r"(?:external|bmt_backend(?:\.[A-Za-z_][A-Za-z_0-9]*)+:[A-Za-z_][A-Za-z_0-9]*:[0-9]+)", str(record.failure_site)):
            value["failure_site"] = record.failure_site
        return json.dumps(value, separators=(",", ":"))


def configure_logging():
    logger = logging.getLogger("bmt")
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False
