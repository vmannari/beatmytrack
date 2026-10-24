"""Review-only SQL counts and lossless transport experiments; no runtime edits."""
from __future__ import annotations

import base64
import gzip
import hashlib
import json
import logging
import random
import struct
import sys
import tempfile
import time
from collections import Counter, defaultdict
from contextlib import contextmanager
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]
logging.disable(logging.CRITICAL)

from bmt_backend.discovery_models import DiscoveryPartition
from bmt_backend.discovery_projection import settle_for_diagnostics, step
from bmt_backend.economy import PRICES, balance
from bmt_backend.economy_models import CoinWallet, CosmeticUnlock, RewardRankCount
from bmt_backend.identity_models import Player
from bmt_backend.reward_ranks import TIERS, TREE_SIZE, percentile_amount, prefix_nodes
from bmt_backend.studio_platform_models import StudioCoinEntry
from bmt_backend.telemetry_queue import prepare
from bmt_backend.track_models import digest
from sqlalchemy import and_, delete, event, insert, or_, select, update
from test_domains import domain, headers, public_course, race
from test_rivalry_appearance import appearance


@contextmanager
def sql_counts(engine):
    statements = []

    def record(_connection, _cursor, statement, *_args):
        statements.append(statement)

    event.listen(engine, "before_cursor_execute", record)
    try:
        yield statements
    finally:
        event.remove(engine, "before_cursor_execute", record)


def counts(statements):
    kinds = Counter(s.lstrip().split()[0].upper() for s in statements)
    return {"total_statements": len(statements), "statement_kinds": dict(kinds)}


def batch_percentiles(session, board, metrics):
    """Prototype only: retain each metric's root, prefixes and integer ties."""
    nodes = {metric: prefix_nodes(ticks) for metric, ticks in metrics.items()}
    rows = session.execute(select(RewardRankCount.metric, RewardRankCount.node, RewardRankCount.total).where(
        RewardRankCount.board_id == board,
        or_(*(and_(RewardRankCount.metric == metric, RewardRankCount.node.in_([TREE_SIZE, *keys]))
              for metric, keys in nodes.items())))).all()
    values = {(metric, node): total for metric, node, total in rows}
    result = {}
    for metric, keys in nodes.items():
        population = values.get((metric, TREE_SIZE), 0)
        rank = sum(values.get((metric, node), 0) for node in keys) + 1
        result[metric] = next((amount for limit, amount in TIERS
                               if population and rank * 100 <= population * limit), 0)
    return result


def rank_probe(d, board):
    populations = {"race": [100 + i // 2 * 10 for i in range(100)],
                   "lap": [10 + i // 2 * 2 for i in range(100)]}
    totals = defaultdict(int)
    for metric, ticks in populations.items():
        for tick in ticks:
            node = tick
            while node <= TREE_SIZE:
                totals[metric, node] += 1
                node += node & -node
    rng = random.Random(145)
    probes = [{"race": t, "lap": l} for t, l in
              [(1, 1), (100, 10), (140, 18), (150, 20), (220, 34),
               (340, 58), (350, 60), (591, 109), (TREE_SIZE - 1, TREE_SIZE - 1)]]
    probes.extend({"race": rng.randint(1, 650), "lap": rng.randint(1, 125)} for _ in range(100))
    engine = d.app.state.engine
    with d.factory() as session:
        session.execute(delete(RewardRankCount).where(RewardRankCount.board_id == board))
        session.execute(insert(RewardRankCount), [{"board_id": board, "metric": m, "node": n, "total": v}
                                                for (m, n), v in totals.items()])
        amounts = Counter()
        for ticks in probes:
            with sql_counts(engine) as old_sql:
                old = {m: percentile_amount(session, board, m, t) for m, t in ticks.items()}
            with sql_counts(engine) as new_sql:
                new = batch_percentiles(session, board, ticks)
            assert old == new
            for metric, tick in ticks.items():
                population = populations[metric]
                rank = 1 + sum(value < tick for value in population)
                oracle = next((amount for limit, amount in TIERS if rank * 100 <= len(population) * limit), 0)
                assert new[metric] == oracle
                amounts[oracle] += 1
            assert len(old_sql) == 2 and len(new_sql) == 1
        session.rollback()
    return {"paired_cases": len(probes), "metric_results_compared": len(probes) * 2,
            "population_per_metric": 100, "tier_results": dict(amounts),
            "current_sql_per_pair": 2, "prototype_sql_per_pair": 1,
            "exact_current_and_independent_oracle_equality": True,
            "limitation": "Single-thread SQLite; PostgreSQL snapshot/lock concurrency not exercised"}


def path_transport_probe():
    source = ROOT / ".tools/trajectory-approved-20261009/proof.json"
    proof = json.loads(source.read_text(encoding="utf-8"))
    path = [[s[0], s[1], s[2], s[6]] for s in proof["samples"]]
    record = struct.Struct("<IddB")
    binary = b"".join(record.pack(*s) for s in path)
    decoded = [list(record.unpack_from(binary, offset)) for offset in range(0, len(binary), record.size)]
    assert decoded == path
    old = {"schema": "bmt-race-path-v1", "input_count": path[-1][0], "samples": path, "rewinds": []}
    new = {"schema": "review-only-f64-path", "input_count": path[-1][0],
           "count": len(path), "packed": base64.b64encode(binary).decode("ascii"), "rewinds": []}
    encode = lambda obj: json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode()
    old_bytes, new_bytes = encode(old), encode(new)
    ghosts = json.loads((ROOT / "docs/evidence/cost-optimisation-implementation-2026-10-24/ghost-wire-fixture.json").read_text())
    old_full, new_full = dict(old, ghost=ghosts["packed"]), dict(new, ghost=ghosts["packed"])
    return {"samples": len(path), "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "float64_exact_roundtrip": True, "codec": "Little-endian uint32 tick, float64 x/y, uint8 layer; base64 JSON",
            "path_current_json_bytes": len(old_bytes), "path_prototype_json_bytes": len(new_bytes),
            "path_current_gzip_bytes": len(gzip.compress(old_bytes, mtime=0)),
            "path_prototype_gzip_bytes": len(gzip.compress(new_bytes, mtime=0)),
            "with_existing_packed_ghost_current_gzip_bytes": len(gzip.compress(encode(old_full), mtime=0)),
            "with_existing_packed_ghost_prototype_gzip_bytes": len(gzip.compress(encode(new_full), mtime=0)),
            "gzip_comparison_by_level": {str(level): {
                "path_current": len(gzip.compress(old_bytes, compresslevel=level, mtime=0)),
                "path_prototype": len(gzip.compress(new_bytes, compresslevel=level, mtime=0)),
                "with_ghost_current": len(gzip.compress(encode(old_full), compresslevel=level, mtime=0)),
                "with_ghost_prototype": len(gzip.compress(encode(new_full), compresslevel=level, mtime=0)),
            } for level in (1, 6, 9)},
            "limitation": "Retained proof and unrelated synthetic packed ghost, gzip level 9, not an actual player upload or mobile CPU measurement"}


def probe(d):
    engine = d.app.state.engine
    version, board = public_course(d)
    race(d, version, "Alice", frames=20)
    with sql_counts(engine) as repeated:
        result = race(d, version, "Alice", frames=40)
    rank_selects = [s for s in repeated if s.lstrip().upper().startswith("SELECT")
                    and "FROM reward_rank_counts" in s]
    achievement_inserts = [s for s in repeated if s.lstrip().upper().startswith("INSERT INTO ACHIEVEMENT_STATES")]
    Path(__file__).with_name("repeat-flow-sql.json").write_text(json.dumps(repeated, indent=2), encoding="utf-8")
    print(json.dumps({"rank_selects": len(rank_selects), "achievement_inserts": len(achievement_inserts)}), flush=True)
    assert len(rank_selects) == 2 and len(achievement_inserts) == 1
    result_out = {"repeat_slower_race": {**counts(repeated), "status": result["status"],
        "rank_selects": len(rank_selects), "achievement_state_conflict_insert_attempts": len(achievement_inserts),
        "scope": "Whole ticket/submission/worker/status flow, not worker-only statement count"}}
    result_out["batched_percentile_prototype"] = rank_probe(d, board)

    warm = d.client.get("/v1/economy", headers=headers(d, "Alice"))
    assert warm.status_code == 200
    with sql_counts(engine) as wallet_sql:
        current = d.client.get("/v1/economy", headers=headers(d, "Alice"))
    with sql_counts(engine) as handler_sql, d.factory() as session:
        handler = balance(session, SimpleNamespace(id=d.players["Alice"]))
    with sql_counts(engine) as coherent_sql, d.factory() as session:
        opening_id = digest({"player": d.players["Alice"], "reference": "opening"})
        query = select(CoinWallet.balance, CoinWallet.revision, CosmeticUnlock.item_id, StudioCoinEntry.id) \
            .select_from(CoinWallet).join(Player, Player.id == CoinWallet.player_id) \
            .outerjoin(CosmeticUnlock, CosmeticUnlock.player_id == CoinWallet.player_id)
        query = query.outerjoin(StudioCoinEntry, StudioCoinEntry.id == opening_id).where(
            CoinWallet.player_id == d.players["Alice"], Player.disabled.is_(False), Player.deleted_at.is_(None)) \
            .order_by(CosmeticUnlock.item_id)
        rows = session.execute(query).all()
        assert rows and rows[0][3] == opening_id
        prototype = {"schema": 1, "balance": rows[0][0], "revision": rows[0][1],
                     "owned": [row[2] for row in rows if row[2] is not None], "prices": PRICES}
    assert current.json() == warm.json() == handler == prototype
    with d.factory() as session:
        session.execute(delete(StudioCoinEntry).where(StudioCoinEntry.id == opening_id))
        assert session.execute(query).first()[3] is None  # Legacy wallet must use locked reconciliation fallback.
        session.rollback()
    for field, value in (("disabled", True), ("deleted_at", int(time.time()))):
        with d.factory() as session:
            setattr(session.get(Player, d.players["Alice"]), field, value)
            session.flush()
            assert session.execute(query).first() is None
            session.rollback()
    with d.factory() as session:
        session.execute(delete(CoinWallet).where(CoinWallet.player_id == d.players["Alice"]))
        assert session.execute(query).first() is None
        session.rollback()
    result_out["established_wallet_read"] = {"current_http_with_fixture_auth": counts(wallet_sql),
        "current_handler_excluding_auth": counts(handler_sql),
        "prototype_coherent_authorised_projection": counts(coherent_sql), "payload_equal": True,
        "opening_marker_present_and_legacy_absence_detected": True,
        "disabled_deleted_and_missing_wallet_detected": True,
        "limitation": "Both handler counts exclude authentication; missing wallet/opening fact requires existing locked initialisation/reconciliation fallback; no concurrent PostgreSQL test"}

    first = d.client.put("/v1/me/appearances", headers=headers(d, "Alice"),
                         json={"appearance": appearance(), "previous": None})
    assert first.status_code == 200
    with sql_counts(engine) as appearance_sql:
        retry = d.client.put("/v1/me/appearances", headers=headers(d, "Alice"),
                             json={"appearance": appearance(), "previous": None})
    assert retry.status_code == 200 and retry.json() == first.json()
    result_out["identical_appearance_retry"] = {**counts(appearance_sql),
        "dummy_player_updates": sum(s.lstrip().upper().startswith("UPDATE PLAYERS SET ID=") for s in appearance_sql),
        "limitation": "SQLite count only; PostgreSQL WAL/MVCC effect inferred from source, not measured"}

    assert prepare(d.factory) == 0
    with sql_counts(engine) as telemetry_sql:
        prepared = [prepare(d.factory) for _ in range(3)]
    assert prepared == [0, 0, 0]
    result_out["idle_telemetry_legacy_preparation"] = {**counts(telemetry_sql), "turns": 3, "receipts_routed": 0}

    stamp = int(time.time())
    settled = settle_for_diagnostics(d.factory, clock=stamp)
    with d.factory() as session:
        session.execute(update(DiscoveryPartition).values(checked_at=time.time_ns(), audit_at=stamp + 60))
        session.commit()
    with sql_counts(engine) as discovery_sql:
        worked = [step(d.factory, clock=stamp) for _ in range(3)]
    assert worked == [False, False, False]
    result_out["idle_discovery"] = {**counts(discovery_sql), "turns": 3, "worked": worked,
        "settle_iterations": settled,
        "partition_updates": sum(s.lstrip().upper().startswith("UPDATE DISCOVERY_PARTITIONS") for s in discovery_sql),
        "setup": "Settled current fixture; all partition health timestamps fresh and audit deadlines in future"}
    result_out["lossless_path_transport_prototype"] = path_transport_probe()
    return result_out


def main():
    names = ["backend/bmt_backend/economy.py", "backend/bmt_backend/reward_ranks.py",
             "backend/bmt_backend/achievements.py", "backend/bmt_backend/discovery_projection.py",
             "backend/bmt_backend/discovery_worker.py", "backend/bmt_backend/telemetry_queue.py",
             "backend/bmt_backend/product_worker.py", "backend/bmt_backend/appearance_routes.py",
             "game/backend/appearance_sync.gd", "game/core/app.gd"]
    hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names}
    with tempfile.TemporaryDirectory(prefix="bmt-further-review-") as folder:
        fixture = domain.__wrapped__(Path(folder), SimpleNamespace(param="sqlite"))
        d = next(fixture)
        try:
            result = probe(d)
        finally:
            fixture.close()
    result["source_sha256"] = hashes
    result["limits"] = ["Disposable SQLite domain fixture and FakeVerifier; no live player data",
                         "Review-only prototypes; runtime and contracts unchanged",
                         "No PostgreSQL/load/device test, attachment check, deployment or owner-process restart"]
    target = Path(__file__).with_name("probe-results.json")
    target.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "source_sha256"}, indent=2))


if __name__ == "__main__":
    main()
