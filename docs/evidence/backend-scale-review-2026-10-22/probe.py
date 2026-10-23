"""Read-only source audit probes; synthetic in-memory data, no configured service.

Run from the repository root with PYTHONPATH=backend. This is an algorithmic
probe, not a PostgreSQL, HTTP, concurrency or deployment capacity benchmark.
"""
from __future__ import annotations

import gc
import json
import sqlite3
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException
from sqlalchemy.dialects import sqlite

from bmt_backend import achievements, economy, histogram_snapshots, studio_finance
from bmt_backend.discovery import Query, _ordered_ids
from bmt_backend.identity_models import Player
from bmt_backend.storage import LocalBlobStore
from bmt_backend.track_models import Board, TrackVersion


def reward_queries():
    """Trace the actual award function while replacing all persistence with stubs."""
    statements = []

    class TraceSession:
        def get(self, model, key):
            if model is Player:
                return SimpleNamespace(is_test_driver=False)
            if model is Board:
                return SimpleNamespace(id="board", version_id="version", manifest={})
            if model is TrackVersion:
                return SimpleNamespace(track_id="track")
            return None

        def scalar(self, statement):
            sql = str(statement.compile(dialect=sqlite.dialect(), compile_kwargs={"literal_binds": True}))
            if "count(" in sql.lower():
                statements.append(sql)
                return 10
            return None

        def add(self, _row):
            pass

        def flush(self):
            pass

    run = SimpleNamespace(id="run", status="verified", player_id="driver", board_id="board",
                          ticket_id="ticket", lap_ticks=[50000] * 5, time_ticks=50000, created_at=0)
    wallet = SimpleNamespace(balance=0, revision=0)
    with patch.object(economy, "locked_wallet", return_value=wallet), \
            patch.object(achievements, "capture_race"), patch.object(studio_finance, "coin_entry"):
        economy.accept_verified(TraceSession(), run, (0, 0))
    assert len(statements) == 4, statements
    return statements


def count_scaling(statements):
    """Run the emitted SELECTs with rank indexes, count SQLite VM work."""
    reports = []
    for size in (1000, 10000, 100000):
        db = sqlite3.connect(":memory:")
        db.executescript("""
            CREATE TABLE players(id TEXT PRIMARY KEY, disabled BOOLEAN, deleted_at INTEGER, is_test_driver BOOLEAN);
            CREATE TABLE personal_bests(board_id TEXT, player_id TEXT, time_ticks INTEGER, PRIMARY KEY(board_id,player_id));
            CREATE TABLE lap_personal_bests(board_id TEXT, player_id TEXT, time_ticks INTEGER, PRIMARY KEY(board_id,player_id));
            CREATE INDEX ix_pb_rank ON personal_bests(board_id,time_ticks,player_id);
            CREATE INDEX ix_news_lap_rank ON lap_personal_bests(board_id,time_ticks,player_id);
        """)
        db.executemany("INSERT INTO players VALUES(?,0,NULL,0)", ((str(i),) for i in range(size)))
        for table in ("personal_bests", "lap_personal_bests"):
            db.executemany(f"INSERT INTO {table} VALUES('board',?,?)", ((str(i), i + 1) for i in range(size)))
        calls = 0

        def progress():
            nonlocal calls
            calls += 1
            return 0

        plans = [[list(row) for row in db.execute("EXPLAIN QUERY PLAN " + sql)] for sql in statements]
        db.set_progress_handler(progress, 100)
        values = [db.execute(sql).fetchone()[0] for sql in statements]
        db.set_progress_handler(None, 0)
        reports.append({"drivers_on_board": size, "counts": values,
                        "sqlite_vm_operations_rounded_down_100": calls * 100, "plans": plans})
        db.close()
    assert reports[1]["sqlite_vm_operations_rounded_down_100"] > reports[0]["sqlite_vm_operations_rounded_down_100"] * 8
    assert reports[2]["sqlite_vm_operations_rounded_down_100"] > reports[1]["sqlite_vm_operations_rounded_down_100"] * 5
    return reports


def oversized_snapshot():
    """Use actual load_snapshot/cache code, with an instrumented SQL adapter.

    A shared synthetic dictionary reduces probe memory; production stores two
    metric dictionaries. Payload serialization/network costs are not measured.
    """
    size = 400000
    own = {str(i): 100 for i in range(size)}
    field = {"own": own, "ticks": [100], "counts": [size], "cumulative": [0, size], "histogram": {"bins": []}}
    payload = {"race": field, "best_lap": field}

    class Bind:
        pass

    class InstrumentedSession:
        def __init__(self):
            self.bind = Bind()
            self.payload_reads = 0

        def get_bind(self):
            return self.bind

        def execute(self, _statement):
            return SimpleNamespace(first=lambda: SimpleNamespace(generation="generation", source_revision=1, invalidated=False))

        def scalar(self, _statement):
            self.payload_reads += 1
            return payload

    session = InstrumentedSession()
    for _ in range(2):
        result = histogram_snapshots.load_snapshot(session, "version", "compact", False)
        assert len(result[2][0].own) == size
    assert session.payload_reads == 2
    return {"drivers": size, "actual_estimated_cache_weight_bytes": 2 * (size * 180 + 96),
            "cache_budget_bytes": 128 * 1024 * 1024, "sequential_calls": 2,
            "full_payload_reads": session.payload_reads,
            "adapter": "instrumented metadata/payload adapter; actual load_snapshot and board_cache"}


def discovery_limit():
    class Session:
        def execute(self, statement):
            assert statement._limit_clause.value == 100001
            return SimpleNamespace(all=lambda: [(str(i), False) for i in range(100001)])

    try:
        _ordered_ids(Session(), Query(), None, 0)
    except HTTPException as error:
        assert error.status_code == 503 and error.detail == "DISCOVERY_CATALOGUE_LIMIT"
        return {"matching_tracks": 100001, "status": error.status_code, "detail": error.detail,
                "adapter": "instrumented SQL result; actual _ordered_ids default path"}
    raise AssertionError("Expected catalogue limit")


def local_listing_scaling():
    """Count actual directory entries advanced by resumable local GC listing.

    Fake directory entries avoid creating files. The real iterator/offset loop
    runs unchanged, including skipped entries that its 'inspected' cap omits.
    """
    reports = []
    for size in (1000, 10000, 100000):
        advanced = 0

        class Scan:
            def __enter__(self):
                def entries():
                    nonlocal advanced
                    for i in range(size):
                        advanced += 1
                        yield SimpleNamespace(name="00" + f"{i:062x}" + ".json",
                            is_file=lambda **_kwargs: True,
                            stat=lambda **_kwargs: SimpleNamespace(st_mtime=0, st_size=1))
                return entries()

            def __exit__(self, *_args):
                pass

        store = object.__new__(LocalBlobStore)
        store.root = Path("synthetic-no-files")
        cursor, pages, returned = None, 0, 0
        with patch.object(Path, "is_dir", lambda path: path.name == "00"), \
                patch.object(Path, "is_symlink", return_value=False), \
                patch("bmt_backend.storage.os.scandir", side_effect=lambda _path: Scan()):
            while True:
                rows, cursor = store.list_objects(cursor, 1000)
                pages += 1
                returned += len(rows)
                if cursor is None:
                    break
        assert returned == size
        assert advanced == size * (size // 1000 + 1) // 2 + size
        reports.append({"objects_in_one_shard": size, "page_size": 1000,
                        "calls": pages, "entries_advanced": advanced, "objects_returned": returned})
    return reports


def main():
    statements = reward_queries()
    result = {"scope": "synthetic in-memory algorithm probes, no live connections",
              "reward_count_statements": statements, "count_scaling": count_scaling(statements),
              "oversized_snapshot": oversized_snapshot(), "discovery_limit": discovery_limit(),
              "local_listing_scaling": local_listing_scaling()}
    gc.collect()
    destination = Path(__file__).with_name("probe-results.json")
    destination.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(destination), "reward_count_statements": len(statements),
                      "vm_work": [r["sqlite_vm_operations_rounded_down_100"] for r in result["count_scaling"]],
                      "local_directory_advances": [r["entries_advanced"] for r in result["local_listing_scaling"]],
                      "oversized_snapshot": result["oversized_snapshot"], "discovery_limit": result["discovery_limit"]}))


if __name__ == "__main__":
    main()
