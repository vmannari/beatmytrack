"""Paired current-fixture SQL/body/request counts; not production bill forecasts."""
import json
import logging
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]
logging.disable(logging.CRITICAL)

from bmt_backend.worker import process_one
from sqlalchemy import event
from test_domains import domain, headers
from test_outcome_reads import queued_challenge


def measure(d, requests):
    statements = []

    def capture(_connection, _cursor, sql, *_args):
        statements.append(sql)

    event.listen(d.app.state.engine, "before_cursor_execute", capture)
    try:
        responses = [d.client.get(path, headers=headers(d, "Bob")) for path in requests]
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", capture)
    assert all(response.status_code == 200 for response in responses)
    return {"requests": len(responses), "sql_statements": len(statements),
            "decoded_body_bytes": sum(len(response.content) for response in responses),
            "content_lengths": [response.headers.get("content-length") for response in responses],
            "content_encodings": [response.headers.get("content-encoding", "identity") for response in responses]}, responses


with tempfile.TemporaryDirectory(prefix="bmt-read-measurement-") as folder:
    fixture = domain.__wrapped__(Path(folder), SimpleNamespace(param="sqlite"))
    d = next(fixture)
    try:
        _challenge, ticket, run = queued_challenge(d)
        result_path = "/v1/challenge-results/" + ticket["ticket_id"]
        full, _ = measure(d, [result_path])
        compact, _ = measure(d, [result_path + "?compact=true"])
        assert compact["sql_statements"] < full["sql_statements"]
        assert compact["decoded_body_bytes"] < full["decoded_body_bytes"]
        assert process_one(d.app)
        run_path = "/v1/runs/" + run["run_id"]
        legacy, old = measure(d, [run_path, "/v1/economy/rewards/" + ticket["ticket_id"], "/v1/economy", result_path])
        combined, new = measure(d, [run_path + "?completion=true"])
        extra = new[0].json()["completion"]
        assert extra["reward"] == old[1].json()
        assert extra["wallet"] == old[2].json()
        assert extra["challenge_result"]["outcome"] == old[3].json()["outcome"]
        assert combined["sql_statements"] < legacy["sql_statements"]
        report = {"pending": {"full": full, "compact": compact}, "terminal": {"legacy": legacy, "combined": combined},
                  "exact_reward_wallet_outcome_match": True,
                  "limits": "Single paired disposable SQLite/PosedVerifier fixture; headers show HTTP representation length, decoded bytes are not billable egress; no population savings claim."}
    finally:
        fixture.close()
Path(__file__).with_name("read-measurements.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
