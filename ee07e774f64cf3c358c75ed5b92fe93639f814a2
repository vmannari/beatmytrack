"""Regression coverage for rejected work, bounded reads and accepted load fixtures."""
import copy
import json
from types import SimpleNamespace

import pytest
from alembic import command
from sqlalchemy import event, or_, select, update
from sqlalchemy.dialects import postgresql
from test_domains import FakeVerifier

from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.load_fixtures import SyntheticVerifier, golden_fixture, load_fixture, pack_replay, seed
from bmt_backend.migrate import configuration
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.receipt_references import FIELDS, reference
from bmt_backend.replay_wire import unpack_replay
from bmt_backend.track_models import IdempotencyRecord, Track, TrackVersion
from bmt_backend.tracks import my_tracks
from bmt_backend.verifier import GodotVerifier, VerificationError
from bmt_backend.worker import process_one
from bmt_backend.worker_lifecycle import WorkerControl, run_worker


def test_retention_reference_update_uses_all_four_migrated_indexes(auth_app):
    with auth_app.state.session_factory() as db:
        owner = Player(display_name="Receipt fixture")
        db.add(owner)
        db.flush()
        db.add_all([IdempotencyRecord(player_id=owner.id, scope="fixture", key=str(i), request_hash="a"*64,
                                     response={"other": i}) for i in range(2000)])
        db.add_all([IdempotencyRecord(player_id=owner.id, scope="fixture", key=field, request_hash="a"*64,
                                     response={field: "retired-id"}) for field in FIELDS])
        db.commit()
        predicate = or_(*(reference(IdempotencyRecord.response, field).in_(["retired-id"]) for field in FIELDS))
        query = update(IdempotencyRecord).where(predicate).values(response={"retired": True})
        compiled = query.compile(dialect=db.bind.dialect, compile_kwargs={"render_postcompile": True})
        plan = db.connection().exec_driver_sql("EXPLAIN QUERY PLAN " + str(compiled),
            tuple(json.dumps(value) if isinstance(value, dict) else value
                  for value in (compiled.params[key] for key in compiled.positiontup))).all()
        details = " ".join(row[3] for row in plan)
        assert "SCAN domain_idempotency" not in details
        assert all(f"ix_retry_{field}" in details for field in FIELDS), details
        assert db.execute(query).rowcount == 4
        db.commit()
        assert db.get(IdempotencyRecord, (owner.id, "fixture", "0")).response == {"other": 0}
        for field in FIELDS:
            assert db.get(IdempotencyRecord, (owner.id, "fixture", field)).response == {"retired": True}
        sql = str(query.compile(dialect=postgresql.dialect(), compile_kwargs={"render_postcompile": True}))
        assert all("->> '" + field + "'" in sql for field in FIELDS)


def test_retention_index_migration_roundtrip_preserves_receipts(auth_app):
    config = configuration(auth_app.state.engine)
    with auth_app.state.session_factory() as db:
        owner = Player(display_name="Migration fixture")
        db.add(owner)
        db.flush()
        identity = (owner.id, "fixture", "permanent-key")
        db.add(IdempotencyRecord(player_id=owner.id, scope=identity[1], key=identity[2], request_hash="b"*64,
                                 response={"run_id": "permanent-reference"}))
        db.commit()
    command.downgrade(config, "0074_shader_profile_receipts")
    command.upgrade(config, "head")
    with auth_app.state.session_factory() as db:
        assert db.get(IdempotencyRecord, identity).response == {"run_id": "permanent-reference"}
    with pytest.raises(ValueError):
        reference(IdempotencyRecord.response, "untrusted-field")


@pytest.mark.parametrize("local_drafts_only", [False, True])
def test_profile_page_batches_tracks_and_scopes_latest_versions(auth_app, local_drafts_only):
    with auth_app.state.session_factory() as db:
        owner, other = Player(display_name="Owner"), Player(display_name="Other")
        db.add_all([owner, other])
        db.flush()
        for i in range(15):
            track = Track(owner_id=owner.id, archived=i == 14, authoring_id=f"own-{i}")
            db.add(track)
            db.flush()
            for number, state in ((1, "published"), (2, "draft")):
                db.add(TrackVersion(track_id=track.id, number=number, name=f"Own {i}-{number}",
                                    content_hash="c"*64, manifest={}, state=state, created_at=i))
        for i in range(25):
            track = Track(owner_id=other.id, authoring_id=f"other-{i}")
            db.add(track)
            db.flush()
            db.add(TrackVersion(track_id=track.id, number=99, name="Foreign", content_hash="d"*64,
                                manifest={}, state="published"))
        db.commit()
        settings = SimpleNamespace(local_drafts_only=local_drafts_only, public_base_url="https://fixture.invalid")
        request = SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(settings=settings)))
        statements = []
        def record(_conn, _cursor, sql, parameters, _context, _many):
            statements.append((sql, parameters))
        event.listen(auth_app.state.engine, "before_cursor_execute", record)
        try:
            page = my_tracks(request, db, owner, offset=0, limit=12, heads=True, profile_stats=True)
        finally:
            event.remove(auth_app.state.engine, "before_cursor_execute", record)
        assert len(page["items"]) == 12 and page["next_offset"] == 12
        assert all(item["creator"] == "Owner" and item["name"] != "Foreign" for item in page["items"])
        assert all(item["name"].endswith("-1" if local_drafts_only else "-2") for item in page["items"])
        assert len(statements) == 2, statements
        sql, parameters = statements[0]
        assert sql.count("tracks.owner_id =") == 2 and list(parameters).count(owner.id) == 2
        plan = db.connection().exec_driver_sql("EXPLAIN QUERY PLAN " + sql, parameters).all()
        assert any("track_versions" in row[3] and "track_id=?" in row[3] for row in plan), plan
        last = my_tracks(request, db, owner, offset=12, limit=12, heads=True, profile_stats=False)
        assert len(last["items"]) == 2 and last["next_offset"] is None
        assert not {item["track_id"] for item in page["items"]} & {item["track_id"] for item in last["items"]}
        history = my_tracks(request, db, owner, offset=0, limit=100, heads=False, profile_stats=False)
        assert len(history["items"]) == (15 if local_drafts_only else 30)


def test_empty_competition_scan_probes_publications_only_once(auth_app, monkeypatch):
    auth_app.state.verifier = FakeVerifier()
    calls = []
    monkeypatch.setattr("bmt_backend.publications.process_one", lambda _app: calls.append(True) and False)
    monkeypatch.setattr("bmt_backend.worker.expire_unserviceable", lambda _app: False)
    assert not process_one(auth_app)
    assert calls == [True]


def test_idle_backoff_resets_on_hint_and_caps_when_listener_is_lost(auth_app):
    control = WorkerControl()
    waits = []
    class Waiter:
        def wait(self, seconds):
            waits.append(seconds)
            if len(waits) == 3:
                return True
            if len(waits) == 6:
                control.request_stop()
            return False
        def set(self):
            pass
    signals = SimpleNamespace(worker=Waiter(), listening=True, open=lambda: None, close=lambda: None,
                              begin_scan=lambda: None, set_idle=lambda _value: None)
    auth_app.state.run_signals = signals
    def job(_app):
        if len(waits) == 5:
            signals.listening = False
        return False
    run_worker(auth_app, job, control=control, install_signals=False, max_idle_seconds=5)
    assert waits == [1, 2, 4, 1, 2, 1]


def test_publication_commit_wakes_competition_but_rollback_does_not(auth_app):
    signals = auth_app.state.run_signals
    with auth_app.state.session_factory() as db:
        owner = Player(display_name="Publication fixture")
        db.add(owner)
        db.commit()
        def intent():
            return PublicationIntent(player_id=owner.id, operation_key="fixture", request_hash="e"*64,
                                     authoring_id="fixture", name="Fixture", content_hash="f"*64,
                                     replay_hash="a"*64, vehicle_id="compact", contract={})
        db.add(intent())
        db.flush()
        assert not signals.worker.is_set()
        db.rollback()
        assert not signals.worker.is_set()
        db.add(intent())
        db.commit()
        assert signals.worker.is_set()
        signals.begin_scan()
        row = db.scalar(select(PublicationIntent))
        row.status = "failed"
        db.commit()
        assert not signals.worker.is_set()
        row.status = "queued"
        db.commit()
        assert signals.worker.is_set()


def test_load_wire_preserves_recorded_proof_and_current_checker_accepts_it():
    fixture = load_fixture()
    decoded = unpack_replay(pack_replay(fixture["replay"]))
    verifier = GodotVerifier(Settings())
    try:
        result = verifier.verify_run(None, decoded, "compact", geometry=fixture["geometry"])
        assert result["time_ticks"] == fixture["time_ticks"] and len(result["lap_ticks"]) == 5
        bad = copy.deepcopy(decoded)
        bad["race_proof"]["samples"][1][1] += 100
        with pytest.raises(VerificationError):
            verifier.verify_run(None, bad, "compact", geometry=fixture["geometry"])
        missing = {key: value for key, value in decoded.items() if key != "race_proof"}
        with pytest.raises(VerificationError, match="trajectory"):
            verifier.verify_run(None, missing, "compact", geometry=fixture["geometry"])
        assert verifier.engine_pid is None
    finally:
        verifier.close()
    legacy = golden_fixture()["replay"]
    legacy["race_proof"] = copy.deepcopy(decoded["race_proof"])
    wire = pack_replay(legacy)
    assert unpack_replay(wire) == legacy
    wire["race_proof"]["samples"][0][1] += 1
    assert legacy["race_proof"] == decoded["race_proof"]


def test_bootstrap_exposes_stable_appearance_contract(auth_client, monkeypatch):
    first = auth_client.get("/v1/bootstrap").json()["appearance_contract"]
    assert len(first) == 64 and auth_client.get("/v1/bootstrap").json()["appearance_contract"] == first
    from bmt_backend import vehicle_appearance
    monkeypatch.setattr(vehicle_appearance, "CATALOG", {**vehicle_appearance.CATALOG, "fixture": True})
    assert auth_client.get("/v1/bootstrap").json()["appearance_contract"] != first


def test_load_seed_serves_current_discovery_and_daily_reads(auth_app, auth_client):
    from bmt_backend.histogram_snapshots import refresh_all_for_diagnostics
    from bmt_backend.track_models import now

    auth_app.state.verifier = SyntheticVerifier(load_fixture())
    data = seed(auth_app, players=6, tracks=5, actors=2)
    refresh_all_for_diagnostics(auth_app)
    headers = {"Authorization": "Bearer " + data["access"][0]}
    paths = ["/v1/track-of-the-day"]
    query = f"day={now()//86400}&version_id={data['versions'][0]}&vehicle_id=compact"
    paths += ["/v1/track-of-the-day/" + path + "?" + query for path in ("limits", "lap-standings")]
    for path in paths:
        response = auth_client.get(path, headers=headers)
        assert response.status_code == 200, (path, response.text)
    response = auth_client.post("/v1/discovery/v3/tracks", json={"query": {}}, headers=headers)
    assert response.status_code == 200 and response.json()["items"], response.text
