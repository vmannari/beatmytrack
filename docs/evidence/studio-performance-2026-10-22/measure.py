"""Alternating before/current Studio report measurements on an owned PG schema."""
import importlib.util
import json
import os
import statistics
import sys
import time
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

from sqlalchemy import create_engine, event, insert, text

from bmt_backend import admin, studio_analysis, studio_catalogue, studio_finance
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.economy_models import CoinWallet
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.studio_platform_models import AnalysisDay, AnalysisPerson, AnalysisSession, AnalysisState, StudioFinanceEvent

OUTPUT = Path(__file__).resolve().parent
ROOT = OUTPUT.parents[2]


def original(name):
    spec = importlib.util.spec_from_file_location("bmt_backend._before_" + name,
        OUTPUT / "before" / ("backend__bmt_backend__" + name + ".py"))
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main():
    url = os.environ["BMT_TEST_DATABASE_URL"]  # supplied only by the owned runner
    schema = "bmt_load_" + uuid4().hex
    control = create_engine(url, hide_parameters=True)
    with control.begin() as db:
        db.execute(text("CREATE SCHEMA " + schema))
    engine = create_engine(url, hide_parameters=True, connect_args={"options": "-c search_path=" + schema})
    try:
        app = create_app(Settings(database_url=url, object_dir=str(ROOT / "build/studio-performance-measure")), engine=engine)
        upgrade(engine)
        count, observed, stamp = 50000, 10000, int(time.time())
        day = stamp // 86400 - 45
        first = day * 86400
        with app.state.session_factory() as db:
            for start in range(0, count, 5000):
                db.execute(insert(Player), [{"id": f"00000000-0000-4000-8000-{i:012x}", "display_name": f"Driver {i:06}",
                    "username_key": f"driver {i:06}", "created_at": first, "disabled": i % 10 == 0,
                    "is_test_driver": i % 2 == 0} for i in range(start, start + 5000)])
                db.execute(insert(CoinWallet), [{"player_id": f"00000000-0000-4000-8000-{i:012x}", "balance": 1000, "revision": 0}
                    for i in range(start, start + 5000)])
                db.execute(insert(StudioFinanceEvent), [{"id": str(uuid4()), "provider": "admob", "reference": f"{i:064x}",
                    "kind": "ad_earnings", "basis": "estimated", "currency": "EUR", "amount_micros": 1000000,
                    "occurred_at": first + i % 1000, "received_at": first + i, "payload_hash": "0" * 64}
                    for i in range(start, start + 5000)])
            for start in range(0, observed, 1000):
                people, days, sessions = [], [], []
                for i in range(start, start + 1000):
                    identity = f"00000000-0000-4000-8000-{i:012x}"
                    people.append({"player_id": identity, "first_at": first + 10, "first_build": "measured", "first_platform": "android",
                        "journey": {"anchor": first + 10, "steps": i % 5, "truncated": False}})
                    sessions.append({"player_id": identity, "session_id": str(uuid4()), "first_at": first + 10,
                        "last_at": first + 100, "foreground_ms": 90000, "build_id": "measured", "platform": "android"})
                    for offset in (0, 1, 7, 30):
                        days.append({"day": day + offset, "player_id": identity, "dimension": "fixture", "build_id": "measured",
                            "platform": "android", "mode": "free_race", "first_at": first + offset * 86400,
                            "last_at": first + offset * 86400, "counters": {"active": 1, "race_started": 3,
                            "race_finished": 2, "race_accepted": 2, "foreground_ms": 90000}})
                db.execute(insert(AnalysisPerson), people)
                db.execute(insert(AnalysisDay), days)
                db.execute(insert(AnalysisSession), sessions)
            state = db.get(AnalysisState, 1)
            state.started_at, state.processed_through, state.latest_client_at = first, stamp, stamp
            db.commit()
        with engine.begin() as db:
            db.exec_driver_sql("ANALYZE")
        request = SimpleNamespace(app=app)
        before = {name: original(name) for name in ("admin", "studio_catalogue", "studio_analysis", "studio_finance")}
        catalog = dict(q="", state="all", population="all", provider="", sort="created", direction="desc", offset=0, limit=25, anchor=stamp)
        analysis = dict(build_id="measured", platform="", mode="", population="all")
        window = first, first + 86400
        cases = {
            "overview": (lambda: before["admin"].overview(request, "analyst", window, days=7),
                         lambda: admin.overview(request, "analyst", window, days=7)),
            "player_directory": (lambda: before["studio_catalogue"].players(request, "analyst", **catalog),
                                 lambda: studio_catalogue.players(request, "analyst", **catalog, cursor="")),
            "activity_tab": (lambda: before["studio_analysis"].behaviour(request, "analyst", window, **analysis),
                             lambda: studio_analysis.behaviour(request, "analyst", window, **analysis, view="activity")),
            "retention_tab": (lambda: before["studio_analysis"].behaviour(request, "analyst", window, **analysis),
                              lambda: studio_analysis.behaviour(request, "analyst", window, **analysis, view="retention")),
            "finance": (lambda: before["studio_finance"].report(request, "analyst", window),
                        lambda: studio_finance.report(request, "analyst", window)),
        }
        recorded = []

        def capture(_connection, _cursor, sql, params, *_args):
            recorded.append((sql, params))

        event.listen(engine, "before_cursor_execute", capture)
        reports = {}
        for label, functions in cases.items():
            samples = [[], []]
            counts = [[], []]
            values = [None, None]
            for iteration in range(8):
                for index in ((0, 1) if iteration % 2 == 0 else (1, 0)):
                    recorded.clear()
                    begin = time.perf_counter()
                    values[index] = functions[index]()
                    elapsed = (time.perf_counter() - begin) * 1000
                    if iteration:
                        samples[index].append(elapsed)
                        counts[index].append(len(recorded))
            if label == "player_directory":
                old, new = [json.loads(value.body) for value in values]
                assert [{k: row[k] for k in new["items"][0]} for row in old["items"]] == new["items"]
            elif label in ("activity_tab", "retention_tab"):
                keys = ("active_players", "counters", "daily") if label == "activity_tab" else ("retention",)
                assert all(values[0][key] == values[1][key] for key in keys)
            elif label == "finance":
                assert values[0]["money"] == values[1]["money"] and values[0]["coins"] == values[1]["coins"]
            reports[label] = {"before_median_ms": round(statistics.median(samples[0]), 3),
                "after_median_ms": round(statistics.median(samples[1]), 3),
                "before_sql": counts[0][0], "after_sql": counts[1][0]}
        event.remove(engine, "before_cursor_execute", capture)
        with engine.connect() as db:
            plans = {"latest_finance_receipt": db.exec_driver_sql(
                "EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) SELECT max(received_at) FROM studio_finance_events").scalar(),
                "directory": db.exec_driver_sql("EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) SELECT id,display_name FROM players ORDER BY created_at DESC,id DESC LIMIT 26").scalar()}
            plans["directory_deep_cursor"] = db.exec_driver_sql(
                "EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) SELECT id,display_name FROM players WHERE (created_at,id)<(%s,%s) ORDER BY created_at DESC,id DESC LIMIT 26",
                (first, "00000000-0000-4000-8000-0000000061a8")).scalar()
        result = {"scope": "Owned local PostgreSQL 17, direct report functions, seven warmed alternating samples; excludes HTTP and middleware",
            "accounts": count, "wallets": count, "observed_players": observed, "analysis_day_rows": observed * 4,
            "reports": reports, "plans": plans}
        (OUTPUT / "measurements.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"accounts": count, "reports": reports}))
    finally:
        engine.dispose()
        with control.begin() as db:
            db.execute(text("DROP SCHEMA " + schema + " CASCADE"))
        control.dispose()


if __name__ == "__main__":
    main()
