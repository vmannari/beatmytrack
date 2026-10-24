"""Review-only probes against the existing disposable SQLite domain fixture."""
from __future__ import annotations

import hashlib
import json
import logging
import sys
import tempfile
from collections import Counter
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]
logging.disable(logging.CRITICAL)

from bmt_backend import challenges, rivalry
from bmt_backend.economy_models import CoinReward
from bmt_backend.track_models import PersonalBest, Run
from bmt_backend.worker import process_one
from sqlalchemy import event
from test_challenges import PosedVerifier, create, join, normal_run
from test_domains import domain, headers, submit
from test_rivalry import join as join_rivalry
from test_rivalry import rivalry_ticket, seed


def probe(d):
    d.app.state.verifier = PosedVerifier()
    versions = seed(d)
    group = join_rivalry(d)["group_id"]
    join_rivalry(d, "Bob")
    first = rivalry_ticket(d, group)
    submit(d, first, "Alice", frames=20)
    assert process_one(d.app)
    slower = rivalry_ticket(d, group)
    slow_run = submit(d, slower, "Alice", frames=40)
    callers = Counter()
    original = rivalry.standings_data

    def count_standings(*args, **kwargs):
        callers[sys._getframe(1).f_code.co_name] += 1
        return original(*args, **kwargs)

    with patch.object(rivalry, "standings_data", count_standings):
        assert process_one(d.app)
    result = d.client.get(f"/v1/rivalry/tickets/{slower['ticket_id']}/result", headers=headers(d, "Alice"))
    assert result.status_code == 200
    outcome = result.json()["outcome"]
    assert outcome["improved"] is False and outcome["points_delta"] == 0
    with d.factory() as session:
        run = session.get(Run, slow_run["run_id"])
        best = session.get(PersonalBest, (run.board_id, run.player_id))
        reward = session.get(CoinReward, run.id)
        rivalry_result = {
            "improved": outcome["improved"], "points_delta": outcome["points_delta"],
            "standings_calls_by_caller": dict(callers),
            "separate_ghost_stored": bool(run.ghost_hash),
            "personal_best_preserved": best.run_id != run.id,
            "reward_amount": reward.amount,
        }

    normal_run(d, versions[0])
    challenge = create(d, versions[0])
    join(d, challenge["code"])
    issued = d.client.post(f"/v1/challenges/{challenge['code']}/tickets", headers=headers(d, "Bob"))
    assert issued.status_code == 201
    pending = issued.json()
    submit(d, pending, "Bob", frames=40)
    queries = []

    def record(_connection, _cursor, statement, *_args):
        queries.append(statement)

    event.listen(d.app.state.engine, "before_cursor_execute", record)
    try:
        with patch.object(challenges, "snapshot", wraps=challenges.snapshot) as snapshots:
            response = d.client.get(f"/v1/challenge-results/{pending['ticket_id']}", headers=headers(d, "Bob"))
            snapshot_count = snapshots.call_count
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", record)
    assert response.status_code == 200 and response.json()["status"] == "queued"
    pending_result = {
        "status": response.json()["status"], "full_challenge_snapshots": snapshot_count,
        "sql_statements": len(queries), "response_body_bytes_before_http_compression": len(response.content),
    }
    return {"slower_rivalry": rivalry_result, "pending_challenge_poll": pending_result}


def main():
    with tempfile.TemporaryDirectory(prefix="bmt-outcome-review-") as folder:
        fixture = domain.__wrapped__(Path(folder), SimpleNamespace(param="sqlite"))
        d = next(fixture)
        try:
            results = probe(d)
        finally:
            fixture.close()
    sources = ["backend/bmt_backend/worker.py", "backend/bmt_backend/rivalry.py",
        "backend/bmt_backend/challenges.py", "backend/bmt_backend/challenge_series.py",
        "backend/bmt_backend/economy.py", "backend/bmt_backend/trajectory_verifier.py",
        "backend/bmt_backend/news.py", "backend/bmt_backend/runs.py",
        "game/backend/cosmetic_economy.gd", "game/backend/backend_client.gd"]
    results["limits"] = ["Disposable SQLite with FakeVerifier/PosedVerifier domain fixtures",
        "Measures current behavior only; no runtime implementation or before/after savings",
        "No production database, deployment, device check or physical-device test"]
    results["source_sha256"] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sources}
    target = Path(__file__).with_name("probe-results.json")
    target.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
