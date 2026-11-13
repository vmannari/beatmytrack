"""Multi-car sporting scenarios, real SQL settlement, frozen history and API fences."""
from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from test_domains import domain as _domain_fixture
from test_world_ranking import LAUNCH, settle

from bmt_backend import world_ranking_build as build
from bmt_backend.identity_models import Player
from bmt_backend.world_ranking_car_models import CarAward, CarCircuit, CarInput, CarStanding, CarWeek, CarWork
from bmt_backend.world_ranking_car_rules import (
    CARS,
    MAX_TOTAL,
    POLICY,
    award,
    car_key,
    overall,
    participation,
    strength,
    update_rating,
)
from bmt_backend.world_ranking_models import (
    Circuit,
    RankingBranch,
    RankingControl,
    RankingPlayer,
    RankingSnapshot,
    RankingStanding,
)
from bmt_backend.world_ranking_rules import WEEK

ranking_domain = _domain_fixture


def test_population_curve_and_smoothing():
    assert participation([0] * 8) == (10000, 0)
    weights = [participation([n] * 8)[0] for n in (0, 10, 100, 500, 1000, 4000, 100000000)]
    assert weights == sorted(weights) and weights[-1] <= 12500
    assert participation([1000] * 8)[0] == 11250
    assert participation([1000] + [0] * 7)[0] < participation([0] * 7 + [1000])[0]
    assert participation([4000] * 8)[0] > participation([100] * 8)[0]


def test_diminishing_contributions_specialists_and_unused_cars():
    def score(values):
        return overall([(car, n, car_key([(LAUNCH + i * WEEK, min(n, 1500), 1)
            for i in range(12 if n > 1500 else 1)])[1]) for car, n in zip(CARS, values)])
    assert score([1000])[0] == 1000
    assert score([900, 850])[0] == 1240
    assert score([850, 800, 750])[0] == 1282
    assert score([600] * 8)[0] == 930
    assert score([1000, 0, 0])[0] == score([1000])[0]
    assert score([900, 850, 800, 700])[0] == score([900, 850, 800])[0]
    assert score([18000] * 8)[0] == MAX_TOTAL == 27900
    assert score([1000, 900])[1] == score([900, 1000])[1]  # car identity cannot break a sporting tie


def test_field_strength_and_evidence_are_independent_of_popularity():
    assert award(1, 1, 12500, 12000) == 0
    assert award(1, 128, 12500, 12000) == 1500
    assert award(1, 128, 10000, 12000) > award(1, 128, 10000, 8000)
    assert award(1, 2) < award(1, 16) < award(1, 128)
    assert award(10, 128, 12500, 12000) > award(1, 128, 10000, 8000)
    assert strength((2100 * 128, 128)) == 11200
    # A tied field cannot mint ability improvements just by completing more attempts.
    assert update_rating(1500, 0, 1, 16, 16, {1500: 16}) == (1500, 1)


def test_shared_skill_seeds_new_cars_and_preserves_established_specialties():
    from types import SimpleNamespace

    from bmt_backend.world_ranking_cars import _seed
    previous = {car: SimpleNamespace(vehicle_id=car, rating=rating, rated_weeks=8, last_rated_week=LAUNCH)
        for car, rating in (("compact", 2000), ("kart", 1000))}
    specialist = _seed({"vehicle_id": "compact"}, previous, LAUNCH+WEEK)
    newcomer = _seed({"vehicle_id": "electric"}, previous, LAUNCH+WEEK)
    assert specialist["rating"] == specialist["strength_rating"] == 2000
    assert newcomer["rating"] == newcomer["strength_rating"] == 1500 and newcomer["rated_weeks"] == 0
    assert _seed({"vehicle_id": "compact"}, previous, LAUNCH+26*WEEK)["rated_weeks"] == 0


def seed_multi(app, monkeypatch, layouts=None, player_ids=(), bonuses=None, seed_strength=1500):
    layouts = layouts or {"compact": [1000, 1001, 1002], "electric": [1002, 1001, 1000]}
    count = max(len(ticks) for ticks in layouts.values())
    monkeypatch.setattr(build, "now", lambda: LAUNCH - 1)
    settings = replace(app.state.settings, world_ranking_launch_week=LAUNCH, world_ranking_batch_size=3)
    build.initialize(app.state.session_factory, LAUNCH)
    with app.state.session_factory() as db:
        branch = db.scalar(select(RankingBranch))
        circuit = Circuit(week_start=LAUNCH, contract_key="a" * 64, policy=POLICY, tracks=[])
        db.add(circuit)
        db.flush()
        snapshot = RankingSnapshot(branch_id=branch.id, circuit_id=circuit.id, week_start=LAUNCH, field_size=count)
        db.add(snapshot)
        db.flush()
        keys = []
        for i in range(count):
            player = db.get(Player, player_ids[i]) if i < len(player_ids) else Player(display_name=f"MultiDriver{i}")
            player.country_code = "FI" if i % 2 else "SE"
            db.add(player)
            db.flush()
            mapped = RankingPlayer(player_id=player.id)
            db.add(mapped)
            db.flush()
            keys.append(mapped.key)
        for car in CARS:
            ticks = layouts.get(car, [])
            weight = (bonuses or {}).get(car, 10000)
            db.add(CarWeek(snapshot_id=snapshot.id, vehicle_id=car, field_size=len(ticks), participation_bps=weight))
            db.add(CarCircuit(circuit_id=circuit.id, vehicle_id=car, contract_key="a" * 64, tracks=[], participation_bps=weight, weights_locked=True))
            for key, tick in zip(keys, ticks):
                if tick is None:
                    continue
                db.add(CarInput(snapshot_id=snapshot.id, vehicle_id=car, player_key=key, country="FI" if key % 2 == 0 else "SE",
                    **{f"t{s}": tick + s for s in range(5)}, rating=1500, strength_rating=seed_strength, rated_weeks=0))
        branch.snapshot_id, branch.phase = snapshot.id, "m_track:0"
        db.commit()
    monkeypatch.setattr(build, "now", lambda: LAUNCH + WEEK)
    from bmt_backend import world_ranking
    monkeypatch.setattr(world_ranking, "now", lambda: LAUNCH + WEEK)
    app.state.settings = settings
    return settings, keys


def test_atomic_multi_car_settlement_and_shared_sporting_ties(auth_app, monkeypatch):
    settings, keys = seed_multi(auth_app, monkeypatch,
        {"compact": [1000, 1001, 1002], "electric": [1002, 1001, 1000]}, bonuses={"compact": 12000})
    for _ in range(12):
        build.step(auth_app.state.session_factory, auth_app.state.blobs, settings)
        with auth_app.state.session_factory() as db:
            assert db.get(RankingControl, 1).published_id is None
    current = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        compact = list(db.scalars(select(CarStanding).where(CarStanding.snapshot_id == current,
            CarStanding.vehicle_id == "compact").order_by(CarStanding.world_rank)))
        volt = list(db.scalars(select(CarStanding).where(CarStanding.snapshot_id == current,
            CarStanding.vehicle_id == "electric").order_by(CarStanding.world_rank)))
        assert compact[0].player_key == keys[0] and volt[0].player_key == keys[2]
        assert compact[0].total == award(1, 3, 12000)
        assert volt[0].total == award(1, 3)
        for row in db.scalars(select(RankingStanding).where(RankingStanding.snapshot_id == current)):
            scores = [(r.vehicle_id, r.total, car_key([(LAUNCH, r.total, r.world_rank)])[1])
                for r in compact + volt if r.player_key == row.player_key]
            assert row.total == overall(scores)[0]
        assert db.scalar(select(func.count()).select_from(CarInput)) == 0
        assert db.scalar(select(func.count()).select_from(CarWork)) == 0


def test_exact_tied_times_keep_shared_places_in_each_car_and_overall(auth_app, monkeypatch):
    settings, _ = seed_multi(auth_app, monkeypatch, {"compact": [1000, 1000, 1001], "electric": [1000, 1000, 1001]})
    current = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        for car in ("compact", "electric"):
            assert list(db.scalars(select(CarStanding.world_rank).where(CarStanding.snapshot_id == current,
                CarStanding.vehicle_id == car).order_by(CarStanding.world_rank))) == [1, 1, 3]
        assert list(db.scalars(select(RankingStanding.world_rank).where(RankingStanding.snapshot_id == current)
            .order_by(RankingStanding.world_rank))) == [1, 1, 3]


def test_http_car_pages_breakdowns_and_cursor_binding(auth_app, auth_client, sign_in, monkeypatch):
    alice = sign_in("MultiAlice")
    settings, _ = seed_multi(auth_app, monkeypatch, {"compact": list(range(1000, 1060)), "electric": list(range(1060, 1000, -1))},
        [alice["player"]["id"]])
    settle(auth_app, settings)
    headers = {"Authorization": "Bearer " + alice["access_token"]}
    board = auth_client.get("/v1/ranking?vehicle_id=compact", headers=headers)
    assert board.status_code == 200, board.text
    data = board.json()
    assert data["car"] == "compact" and len(data["items"]) == 50 and data["next_cursor"]
    cursor = data["next_cursor"]
    assert auth_client.get("/v1/ranking", params={"vehicle_id": "electric", "cursor": cursor}, headers=headers).status_code == 422
    more = auth_client.get("/v1/ranking", params={"vehicle_id": "compact", "cursor": cursor}, headers=headers)
    assert len(more.json()["items"]) == 10
    own = auth_client.get("/v1/ranking/me", headers=headers)
    assert own.status_code == 200, own.text
    assert own.json()["car"] == "overall" and len(own.json()["cars"]) == 2
    assert own.json()["results"] == []
    car = auth_client.get("/v1/ranking/me?vehicle_id=electric", headers=headers)
    assert car.status_code == 200, car.text
    assert car.json()["world_rank"] == 60 and len(car.json()["results"]) == 1
    assert auth_client.get("/v1/ranking?vehicle_id=unknown", headers=headers).status_code == 422
    assert auth_client.get("/v1/ranking/me?vehicle_id=unknown", headers=headers).status_code == 422
    assert auth_client.get("/v1/ranking/me", headers={**headers, "If-None-Match": own.headers["etag"]}).status_code == 304


def test_staff_inspection_and_preview_keep_car_scope_without_writes(auth_app, auth_client, monkeypatch):
    from bmt_backend.world_ranking_models import RankingCorrection
    settings, keys = seed_multi(auth_app, monkeypatch)
    settings = replace(settings, admin_owner_key="ranking-owner-private-key-0123456789")
    auth_app.state.settings = settings
    current = settle(auth_app, settings)
    headers = {"Authorization": "Bearer " + settings.admin_owner_key}
    with auth_app.state.session_factory() as db:
        circuit_id = db.get(RankingSnapshot, current).circuit_id
        player_id = db.get(RankingPlayer, keys[0]).player_id
    inspection = auth_client.get("/v1/admin/studio/ranking", headers=headers)
    assert inspection.status_code == 200, inspection.text
    assert inspection.json()["circuits"][0]["policy"] == POLICY
    assert {r["vehicle_id"] for r in inspection.json()["circuits"][0]["cars"]} >= {"compact", "electric"}
    body = {"command_id": str(uuid4()), "expected_snapshot": current, "circuit_id": circuit_id,
        "player_id": player_id, "vehicle_id": "electric", "reason": "Scoped owner review only"}
    preview = auth_client.post("/v1/admin/studio/ranking/correction-preview", headers=headers, json=body)
    assert preview.status_code == 200, preview.text
    assert preview.json()["command"]["vehicle_id"] == "electric" and "electric" in preview.json()["effect"]
    invalid = auth_client.post("/v1/admin/studio/ranking/correction-preview", headers=headers,
        json={**body, "vehicle_id": "unknown"})
    assert invalid.status_code == 422
    with auth_app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(RankingCorrection)) == 0
        assert db.get(RankingControl, 1).published_id == current


def test_car_specific_correction_rebuild_preserves_other_car(auth_app, auth_client, monkeypatch):
    settings, keys = seed_multi(auth_app, monkeypatch)
    settings = replace(settings, admin_owner_key="ranking-owner-private-key-0123456789")
    auth_app.state.settings = settings
    original = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        circuit = db.get(RankingSnapshot, original).circuit_id
        target = db.get(RankingPlayer, keys[0]).player_id
        volt_points = db.get(CarStanding, (original, "electric", keys[0])).total
        original_country = db.get(CarStanding, (original, "electric", keys[0])).country
        db.get(Player, target).country_code = "US"
        db.commit()
    response = auth_client.post("/v1/admin/ranking/corrections", headers={"Authorization": "Bearer " + settings.admin_owner_key},
        json={"command_id": str(uuid4()), "expected_snapshot": original, "circuit_id": circuit,
              "player_id": target, "vehicle_id": "compact", "reason": "Invalid Compact result only"})
    assert response.status_code == 200, response.text
    build.step(auth_app.state.session_factory, auth_app.state.blobs, settings)
    with auth_app.state.session_factory() as db:
        assert db.get(RankingControl, 1).published_id == original
    corrected = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        assert db.get(CarStanding, (corrected, "compact", keys[0])) is None
        assert db.get(CarStanding, (corrected, "electric", keys[0])).total == volt_points
        assert db.get(CarStanding, (corrected, "electric", keys[0])).country == original_country
        assert db.scalar(select(func.count()).select_from(CarAward).where(CarAward.branch_id == db.get(RankingSnapshot, corrected).branch_id,
            CarAward.vehicle_id == "compact")) == 2


def test_announced_weights_use_only_prior_published_populations_and_remain_locked(auth_app):
    from bmt_backend.world_circuit import lock_weights
    with auth_app.state.session_factory() as db:
        branch = RankingBranch(next_week=LAUNCH)
        db.add(branch)
        db.flush()
        for age in range(8, 0, -1):
            circuit = Circuit(week_start=LAUNCH-age*WEEK, contract_key="", policy=POLICY, tracks=[])
            db.add(circuit)
            db.flush()
            source = RankingSnapshot(branch_id=branch.id, circuit_id=circuit.id, week_start=circuit.week_start,
                published_at=LAUNCH-age*WEEK+WEEK, state="complete")
            db.add(source)
            db.flush()
            circuit.original_snapshot = source.id
            for car, population in (("compact", 4000), ("electric", 2000), ("hovercraft", 100)):
                db.add(CarWeek(snapshot_id=source.id, vehicle_id=car, field_size=population))
            if age == 1:
                source.published_at = LAUNCH+1  # late settlement cannot alter an announced week
        current = Circuit(week_start=LAUNCH, contract_key="", policy=POLICY, tracks=[])
        db.add(current)
        db.flush()
        for car in ("compact", "electric", "hovercraft"):
            db.add(CarCircuit(circuit_id=current.id, vehicle_id=car, contract_key="", tracks=[]))
        db.flush()
        lock_weights(db, current)
        values = {r.vehicle_id: r.participation_bps for r in db.scalars(select(CarCircuit).where(CarCircuit.circuit_id == current.id))}
        assert values["compact"] == participation([4000]*7+[0])[0]
        assert values["compact"] > values["electric"] > values["hovercraft"] >= 10000
        for source in db.scalars(select(CarWeek)):
            source.field_size *= 10
        db.flush()
        lock_weights(db, current)
        assert {r.vehicle_id: r.participation_bps for r in db.scalars(select(CarCircuit).where(CarCircuit.circuit_id == current.id))} == values


def test_future_weights_use_a_published_correction_without_repricing_open_week(auth_app):
    from bmt_backend.world_circuit import lock_weights
    with auth_app.state.session_factory() as db:
        old = RankingBranch(next_week=LAUNCH)
        corrected = RankingBranch(next_week=LAUNCH)
        db.add_all([old, corrected])
        db.flush()
        historic = Circuit(week_start=LAUNCH-WEEK, contract_key="", policy=POLICY, tracks=[])
        db.add(historic)
        db.flush()
        original = RankingSnapshot(branch_id=old.id, circuit_id=historic.id, week_start=historic.week_start,
            published_at=LAUNCH, state="complete")
        replacement = RankingSnapshot(branch_id=corrected.id, circuit_id=historic.id, week_start=historic.week_start,
            published_at=LAUNCH+1, state="complete")
        db.add_all([original, replacement])
        db.flush()
        db.add_all([CarWeek(snapshot_id=original.id, vehicle_id="compact", field_size=4000),
            CarWeek(snapshot_id=replacement.id, vehicle_id="compact", field_size=100)])
        opened = Circuit(week_start=LAUNCH, contract_key="", policy=POLICY, tracks=[])
        future = Circuit(week_start=LAUNCH+WEEK, contract_key="", policy=POLICY, tracks=[])
        db.add_all([opened, future])
        db.flush()
        for circuit in (opened, future):
            db.add(CarCircuit(circuit_id=circuit.id, vehicle_id="compact", contract_key="", tracks=[]))
        db.flush()
        lock_weights(db, opened)
        locked = db.get(CarCircuit, (opened.id, "compact"))
        before = locked.participation_bps
        assert locked.population_snapshot == original.id
        lock_weights(db, future)
        after = db.get(CarCircuit, (future.id, "compact"))
        assert after.population_snapshot == replacement.id and after.participation_bps < before
        assert locked.participation_bps == before


def test_public_car_enrollment_free_resumes_and_complete_only_freeze(ranking_domain, monkeypatch):
    from test_domains import headers
    from test_rivalry import rivalry_ticket, seed

    from bmt_backend import resumes, rivalry, rivalry_planning
    from bmt_backend.rivalry_models import RivalryBest
    from bmt_backend.track_models import Run
    from bmt_backend.world_circuit import ensure_circuits
    from bmt_backend.world_ranking_car_models import CarEntry

    app = ranking_domain.app
    original_manifest = app.state.verifier.manifest
    def manifest():
        value = original_manifest()
        value["vehicles"]["electric"] = {"handling_version": "volt-test", "config_hash": "volt-test"}
        return value
    monkeypatch.setattr(app.state.verifier, "manifest", manifest)
    monkeypatch.setattr(rivalry, "now", lambda: LAUNCH+20)
    monkeypatch.setattr(resumes, "now", lambda: LAUNCH+20)
    settings = replace(app.state.settings, world_ranking_launch_week=LAUNCH, world_ranking_batch_size=3)
    app.state.settings = settings
    seed(ranking_domain)
    active = manifest()
    with ranking_domain.factory() as db:
        for car in ("compact", "electric"):
            rivalry_planning.ensure_vehicle(db, active, car, LAUNCH-60)
        ensure_circuits(db, app, active, LAUNCH-60)
        db.commit()
    groups = {}
    for car in ("compact", "electric"):
        for name in ("Alice", "Bob"):
            response = ranking_domain.client.post("/v1/rivalry/join", json={"vehicle_id": car}, headers=headers(ranking_domain, name))
            assert response.status_code == 200, response.text
            group = response.json()
            assert group["vehicle_id"] == car and group["world_circuit"]["official"]
            groups[(car, name)] = group
            repeated = ranking_domain.client.post("/v1/rivalry/join", json={"vehicle_id": car}, headers=headers(ranking_domain, name))
            assert repeated.status_code == 200 and repeated.json()["group_id"] == group["group_id"]
            for slot in range(4 if car == "electric" and name == "Bob" else 5):
                ticket = rivalry_ticket(ranking_domain, group["group_id"], name, slot)
                if slot == 0 and name == "Alice":
                    wallet = ranking_domain.client.get("/v1/resumes", params={"ticket_id": ticket["ticket_id"]}, headers=headers(ranking_domain, name))
                    assert wallet.json()["circuit_free"] is True
                    begin = ranking_domain.client.post("/v1/resume-races", json={"ticket_id": ticket["ticket_id"]}, headers=headers(ranking_domain, name))
                    assert begin.status_code == 201, begin.text
                with ranking_domain.factory() as db:
                    ticks = 1000+slot+(10 if name == "Bob" else 0)
                    run = Run(ticket_id=ticket["ticket_id"], player_id=ranking_domain.players[name], board_id=ticket["board_id"],
                        replay_hash="0"*64, status="verified", time_ticks=ticks, created_at=LAUNCH+30, finished_at=LAUNCH+40)
                    db.add(run)
                    db.flush()
                    db.add(RivalryBest(group_id=group["group_id"], player_id=ranking_domain.players[name], slot=slot, run_id=run.id, time_ticks=ticks))
                    db.commit()
    with ranking_domain.factory() as db:
        assert db.scalar(select(func.count()).select_from(CarEntry)) == 4
    monkeypatch.setattr(build, "now", lambda: LAUNCH-1)
    build.initialize(ranking_domain.factory, LAUNCH)
    monkeypatch.setattr(build, "now", lambda: LAUNCH+WEEK)
    current = settle(app, settings)
    with ranking_domain.factory() as db:
        assert db.get(CarWeek, (current, "compact")).field_size == 2
        assert db.get(CarWeek, (current, "electric")).field_size == 1
        assert list(db.scalars(select(CarAward.points).where(CarAward.vehicle_id == "electric"))) == [0]


@pytest.mark.parametrize("count", [1, 16, 127, 128])
def test_sql_awards_match_integer_rules_at_evidence_boundary(auth_app, monkeypatch, count):
    settings, _ = seed_multi(auth_app, monkeypatch, {"compact": list(range(1000, 1000+count))},
        bonuses={"compact": 12500}, seed_strength=2100)
    settings = replace(settings, world_ranking_batch_size=256)
    current = settle(auth_app, settings)
    expected_strength = strength((2100 * count, count))
    with auth_app.state.session_factory() as db:
        assert db.get(CarWeek, (current, "compact")).strength_bps == expected_strength
        for result in db.scalars(select(CarAward).where(CarAward.vehicle_id == "compact")):
            assert result.points == award(result.weekly_place, count, 12500, expected_strength)


def test_per_car_history_survives_switching_cars_in_another_week(auth_app, monkeypatch):
    settings, keys = seed_multi(auth_app, monkeypatch, {"compact": [1000, 1001, 1002]})
    first = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        control = db.get(RankingControl, 1)
        branch = db.get(RankingBranch, control.running_branch)
        event = Circuit(week_start=LAUNCH+WEEK, contract_key="", policy=POLICY, tracks=[])
        db.add(event)
        db.flush()
        snapshot = RankingSnapshot(branch_id=branch.id, circuit_id=event.id, week_start=event.week_start,
            previous_id=first, field_size=3)
        db.add(snapshot)
        db.flush()
        for car in CARS:
            db.add(CarWeek(snapshot_id=snapshot.id, vehicle_id=car, field_size=3 if car == "electric" else 0))
        for index, key in enumerate(keys):
            db.add(CarInput(snapshot_id=snapshot.id, vehicle_id="electric", player_key=key, country="SE",
                **{f"t{s}": 1000+index+s for s in range(5)}, rating=1500, strength_rating=1500, rated_weeks=0))
        branch.snapshot_id, branch.phase = snapshot.id, "m_track:0"
        db.commit()
    monkeypatch.setattr(build, "now", lambda: LAUNCH+2*WEEK)
    second = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        for key in keys:
            original = db.get(CarStanding, (first, "compact", key))
            compact = db.get(CarStanding, (second, "compact", key))
            volt = db.get(CarStanding, (second, "electric", key))
            assert compact.total == original.total and compact.rated_weeks == original.rated_weeks
            assert db.get(RankingStanding, (second, key)).total == (max(compact.total, volt.total)*100 + min(compact.total, volt.total)*40)//100


def test_new_schema_matches_models_and_populated_downgrade_refuses_loss(auth_app, monkeypatch):
    from alembic import command
    from sqlalchemy import inspect

    from bmt_backend.db import Base
    from bmt_backend.migrate import configuration
    inspector = inspect(auth_app.state.engine)
    for name, table in Base.metadata.tables.items():
        if not name.startswith("world_car_"):
            continue
        assert {column.name for column in table.columns} == {column["name"] for column in inspector.get_columns(name)}
        assert {index.name for index in table.indexes} == {index["name"] for index in inspector.get_indexes(name)}
    settings, _ = seed_multi(auth_app, monkeypatch)
    settle(auth_app, settings)
    with pytest.raises(RuntimeError, match="Cannot discard populated"):
        command.downgrade(configuration(auth_app.state.engine), "0075_receipt_reference_indexes")


def test_archive_write_failure_retries_without_duplicate_awards(auth_app, monkeypatch):
    settings, _ = seed_multi(auth_app, monkeypatch)
    original_put = auth_app.state.blobs.put_json
    failed = []
    def interrupt(payload):
        result = original_put(payload)
        if payload.get("policy") == POLICY and payload.get("vehicle_id") and not failed:
            failed.append(True)
            raise RuntimeError("Interrupted after durable object write")
        return result
    monkeypatch.setattr(auth_app.state.blobs, "put_json", interrupt)
    with pytest.raises(RuntimeError, match="Interrupted after durable"):
        for _ in range(80):
            build.step(auth_app.state.session_factory, auth_app.state.blobs, settings)
    with auth_app.state.session_factory() as db:
        assert db.get(RankingControl, 1).published_id is None
    monkeypatch.setattr(build, "now", lambda: LAUNCH+WEEK+6)
    current = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(CarAward)) == 6
        assert db.scalar(select(func.count()).select_from(RankingStanding).where(RankingStanding.snapshot_id == current)) == 3


def test_multi_car_expiry_removes_points_and_retains_career(auth_app, monkeypatch):
    settings, _ = seed_multi(auth_app, monkeypatch)
    settings = replace(settings, world_ranking_batch_size=256)
    settle(auth_app, settings)
    for age in range(1, 27):
        monkeypatch.setattr(build, "now", lambda age=age: LAUNCH+(age+1)*WEEK)
        current = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        from bmt_backend.world_ranking_models import RankingCareer
        assert db.scalar(select(func.count()).select_from(RankingStanding).where(RankingStanding.snapshot_id == current)) == 0
        assert db.scalar(select(func.count()).select_from(CarStanding).where(CarStanding.snapshot_id == current)) == 0
        assert db.scalar(select(func.count()).select_from(RankingCareer)) > 0
