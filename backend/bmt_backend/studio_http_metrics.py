"""Observe server SLOs from bounded exports of existing structured request logs.

Accepts Cloud Logging JSONL entries (timestamp + jsonPayload), retaining only
aggregate counts. No player, request ID, query, payload or credential is uploaded.
Collection completeness is an operator assertion, not inferred from missing logs.
"""

import argparse
import json
import math
import os
from datetime import datetime
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

import requests
from fastapi import HTTPException

from .track_models import digest, now

WINDOWS = (300, 3600, 21600)


def validate_report(value):
    if (
        not isinstance(value, dict)
        or set(value) != {"complete", "until", "windows", "definition"}
        or type(value["complete"]) is not bool
    ):
        raise HTTPException(422, "INVALID_HTTP_AGGREGATES")
    if (
        type(value["until"]) is not int
        or not isinstance(value["windows"], list)
        or len(value["windows"]) != 3
        or value["definition"] != "server-http-v1"
    ):
        raise HTTPException(422, "INVALID_HTTP_AGGREGATES")
    if value["until"] < 1 or value["until"] % 60:
        raise HTTPException(422, "INVALID_HTTP_AGGREGATES")
    previous = {"requests": 0, "server_errors": 0, "over_1000ms": 0}
    for row, seconds in zip(value["windows"], WINDOWS, strict=True):
        if (
            not isinstance(row, dict)
            or set(row) != {"seconds", "requests", "server_errors", "over_1000ms"}
            or row["seconds"] != seconds
        ):
            raise HTTPException(422, "INVALID_HTTP_AGGREGATES")
        if any(type(v) is not int or not 0 <= v <= 1000000000 for v in row.values()) or any(
            row[k] > row["requests"] for k in ("server_errors", "over_1000ms")
        ):
            raise HTTPException(422, "INVALID_HTTP_AGGREGATES")
        if any(row[k] < previous[k] for k in previous):
            raise HTTPException(422, "INVALID_HTTP_AGGREGATES")
        previous = row


def aggregate(lines, *, until, complete):
    rows = {
        seconds: {"seconds": seconds, "requests": 0, "server_errors": 0, "over_1000ms": 0}
        for seconds in WINDOWS
    }
    seen = set()
    ignored = 0
    for line in lines:
        if len(seen) >= 100000:
            complete = False
            break
        try:
            envelope = json.loads(line)
            data = envelope.get("jsonPayload", envelope)
            if (
                data.get("event") != "http_request"
                or not str(data.get("route", "")).startswith("/v1/")
                or str(data.get("route", "")).startswith("/v1/admin/")
            ):
                continue
            timestamp = datetime.fromisoformat(envelope["timestamp"].replace("Z", "+00:00"))
            if timestamp.utcoffset() is None:
                raise ValueError("timezone required")
            at = timestamp.timestamp()
            status, duration = data["status"], data["duration_ms"]
            if (
                type(status) is not int
                or not 100 <= status <= 599
                or type(duration) not in (int, float)
                or not math.isfinite(duration)
                or not 0 <= duration <= 600000
            ):
                raise ValueError("invalid counters")
            identity = str(data["request_id"])
            if not 1 <= len(identity) <= 80:
                raise ValueError("invalid identity")
            if identity in seen:
                continue
            seen.add(identity)
            for seconds, row in rows.items():
                if until - seconds <= at < until:
                    row["requests"] += 1
                    row["server_errors"] += status >= 500
                    row["over_1000ms"] += duration > 1000
        except (ValueError, TypeError, KeyError, AttributeError):
            ignored += 1
            complete = False
    result = {
        "complete": complete,
        "until": until,
        "windows": list(rows.values()),
        "definition": "server-http-v1",
    }
    validate_report(result)
    return result, ignored


def signals(report):
    by = {row["seconds"]: row for row in report["windows"]}

    def burn(row, key, budget):
        return row[key] / row["requests"] / budget if row["requests"] else 0

    result = []
    for key, field, budget, title in [
        ("server_error_budget", "server_errors", 0.001, "Server availability error budget is burning"),
        ("server_latency_budget", "over_1000ms", 0.01, "Server latency budget is burning"),
    ]:
        known = report["complete"] and all(r["requests"] >= 100 for r in by.values())
        active = (burn(by[300], field, budget) > 14.4 and burn(by[3600], field, budget) > 14.4) or (
            burn(by[3600], field, budget) > 6 and burn(by[21600], field, budget) > 6
        )
        evidence = "; ".join(
            str(r[field]) + "/" + str(r["requests"]) + " over " + str(r["seconds"]) + "seconds"
            for r in by.values()
        )
        result.append(
            {
                "key": key,
                "active": active if known else None,
                "severity": "critical",
                "title": title,
                "evidence": evidence,
                "next_step": "Inspect the affected API revision and request logs; compare worker queues and dependency health. Sparse or incomplete logs do not establish healthy service.",
                "target": "system",
            }
        )
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jsonl", type=Path, required=True)
    parser.add_argument("--complete-six-hour-export", action="store_true")
    args = parser.parse_args()
    if args.jsonl.stat().st_size > 64 * 1024 * 1024:
        parser.error("Use a bounded export up to64MiB; split collection upstream")
    until = now() // 60 * 60
    with args.jsonl.open(encoding="utf-8") as stream:
        report, ignored = aggregate(stream, until=until, complete=args.complete_six_hour_export)
    source = os.environ["STUDIO_HTTP_SOURCE"]
    base = os.environ["STUDIO_HTTP_URL"].rstrip("/")
    from urllib.parse import urlsplit

    url = urlsplit(base)
    if url.scheme != "https" or not url.hostname or url.username or url.password or url.query or url.fragment:
        parser.error("Explicit HTTPS origin required")
    token = os.environ["STUDIO_HTTP_TOKEN"]
    if len(token) < 32:
        parser.error("Dedicated source token required")
    body = {
        "id": str(uuid5(NAMESPACE_URL, "bmt-http:" + source + ":" + digest(report))),
        "observed_at": until,
        "signals": signals(report),
        "http": report,
    }
    response = requests.post(
        base + "/v1/monitor/" + source + "/observations",
        json=body,
        headers={"Authorization": "Bearer " + token},
        timeout=10,
        allow_redirects=False,
    )
    if response.status_code != 200:
        raise RuntimeError("HTTP_OBSERVATION_NOT_ACCEPTED")
    print(json.dumps({"accepted": True, "ignored": ignored, "complete": report["complete"]}))


if __name__ == "__main__":
    main()
