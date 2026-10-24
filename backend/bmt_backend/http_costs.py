"""Bounded all-request cost counters; routine success detail is independently sampled."""
import json
import logging
import threading
import time

log = logging.getLogger("bmt.requests")
LIMITS = (10, 25, 50, 100, 250, 500, 1000, 5000)


class HttpCostCounters:
    def __init__(self, settings, *, clock=time.monotonic):
        self.interval = settings.http_metrics_interval_seconds
        self.sample = settings.http_success_sample_per_mille
        self.clock, self.lock = clock, threading.Lock()
        self.started, self.rows = clock(), {}

    def observe(self, value):
        tick = self.clock()
        emitted = None
        key = value["route"], value["method"], value["status"]
        with self.lock:
            if tick-self.started >= self.interval:
                emitted = self._snapshot(tick)
                self.rows, self.started = {}, tick
            if key not in self.rows and len(self.rows) >= 512:
                key = "other", "OTHER", 0
            row = self.rows.setdefault(key, {"requests": 0, "request_wire_bytes": 0, "response_wire_bytes": 0,
                                            "duration_ms": 0.0, "max_ms": 0.0, "latency_buckets": [0]*9})
            row["requests"] += 1
            for name in ("request_wire_bytes", "response_wire_bytes", "duration_ms"):
                row[name] += value[name]
            row["max_ms"] = max(row["max_ms"], value["duration_ms"])
            bucket = next((i for i, limit in enumerate(LIMITS) if value["duration_ms"] <= limit), len(LIMITS))
            row["latency_buckets"][bucket] += 1
        if emitted and emitted["rows"]:
            # One bounded summary per interval, not an event per successful request.
            log.info(json.dumps(emitted, separators=(",", ":")))
        sampled = int(value["request_id"].replace("-", "")[-8:], 16) % 1000 < self.sample
        if value["status"] >= 400 or value["duration_ms"] >= 1000 or sampled:
            log.info(json.dumps({**value, "success_sample_per_mille": self.sample}, separators=(",", ":")))

    def _snapshot(self, tick):
        return {"event": "http_cost_summary", "interval_seconds": round(tick-self.started, 3),
                "body_bytes_after_compression": True, "latency_limits_ms": list(LIMITS),
                "rows": [{"route": route, "method": method, "status": status, **row,
                          "latency_buckets": list(row["latency_buckets"])}
                         for (route, method, status), row in self.rows.items()]}

    def snapshot(self):
        with self.lock:
            return self._snapshot(self.clock())

    def flush(self):
        with self.lock:
            value = self._snapshot(self.clock())
            self.rows, self.started = {}, self.clock()
        if value["rows"]:
            log.info(json.dumps(value, separators=(",", ":")))
