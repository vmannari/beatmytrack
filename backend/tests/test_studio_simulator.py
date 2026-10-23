"""Population coherence, real projection, resumption and production fences."""

from dataclasses import replace
from uuid import NAMESPACE_URL, uuid5

import pytest
from sqlalchemy import func, select
from test_domains import domain, public_course, race  # noqa: F401

from bmt_backend.config import Settings
from bmt_backend.economy_models import CoinWallet
from bmt_backend.identity_models import Player
from bmt_backend.race_statistics_models import RaceStatisticsDay
from bmt_backend.studio_platform_models import (
    AnalysisDay,
    AnalysisPerson,
    AnalysisSession,
    StudioCoinEntry,
    StudioIncident,
)
from bmt_backend.studio_simulator import (
    BUILDS,
    DAY,
    DEVICES,
    Plan,
    Simulator,
    identity,
    network_package,
    race_package,
)
from bmt_backend.track_models import OperationState, Run, now


def plan():
    return Plan("studio-contract", 12, 40, 1701, now() - 120)


def prepared(domain):  # noqa: F811
    version, _ = public_course(domain)
    race(domain, version, frames=60)
    return Simulator(domain.factory, domain.app.state.settings, plan())


def counts(domain):  # noqa: F811
    with domain.factory() as db:
        return {
            model.__tablename__: db.scalar(select(func.count()).select_from(model))
            for model in (
                Player,
                Run,
                AnalysisDay,
                AnalysisPerson,
                AnalysisSession,
                StudioCoinEntry,
                StudioIncident,
            )
        }


def test_contracts_cover_devices_and_regression_without_invalid_counters():
    from bmt_backend.studio_simulator import rng_for

    p = plan()
    for device in DEVICES:
        for build in BUILDS:
            package = race_package(
                rng_for(p, device[1], build),
                device,
                build,
                identity("race"),
                identity("track"),
                120000,
                "finished",
                [[0, 0], [20, 20], [0, 0]],
            )
            assert (
                sum(row[2] for row in package["cells"])
                == package["position_samples"]
                == sum(row[1] for row in package["segments"])
            )
            for category in ("discovery", "score_upload"):
                for bad in (False, True):
                    assert network_package(device, category, bad)["attempts"] == 10
    with pytest.raises(ValueError):
        Plan(players=1, anchor=now()).validate()
    with pytest.raises(ValueError):
        Plan(dataset="bad/identifier", anchor=now()).validate()
    with pytest.raises(ValueError):
        Simulator(None, Settings(environment="production"), p)


def test_server_track_references_accept_legacy_uuid5_but_client_race_ids_remain_uuid4():
    from bmt_backend.race_statistics import validate
    from bmt_backend.studio_simulator import rng_for

    legacy = str(uuid5(NAMESPACE_URL, "published-track-version"))
    package = race_package(
        rng_for(plan(), "legacy"),
        DEVICES[0],
        BUILDS[0],
        identity("race"),
        legacy,
        120000,
        "finished",
        [[0, 0], [20, 20]],
    )
    assert package["track_version_id"] == legacy
    with pytest.raises(ValueError):
        validate({**package, "race_id": legacy})


def test_finished_race_time_and_submission_latency_are_coherent_at_day_boundary():
    p = replace(plan(), anchor=(now() // DAY - 1) * DAY + 720)
    template = {
        "version_id": identity("track"),
        "vehicle": "compact",
        "biome": "pine",
        "time_ticks": 216000,
        "points": [[0, 0], [20, 20]],
        "lap_ticks": [43200] * 5,
    }
    sim = Simulator(None, Settings(environment="test"), p, templates=[template])
    for index in range(p.players):
        rows, races = sim.events(p.person(index), p.anchor // DAY, 0)
        assert not races
        assert all(r["properties"]["outcome"] != "finished" for r in rows if r["name"] == "race_statistics")


def test_simulator_ordinary_players_projection_balanced_economy_and_workflows(domain):  # noqa: F811
    sim = prepared(domain)
    domain.app.state.settings = replace(
        domain.app.state.settings,
        admin_owner_key="o" * 40,
        telemetry_enabled=True,
        client_quality_enabled=True,
    )
    with domain.factory() as db:
        original = {
            p.id: (p.display_name, p.created_at, p.is_test_driver) for p in db.scalars(select(Player))
        }
    result = sim.history(progress=lambda *_args, **_kwargs: None)
    assert result["complete"] and result["accepted_races"] > 20 and result["events"] > 200
    with domain.factory() as db:
        people = db.scalars(
            select(Player).where(Player.id.in_([sim.plan.person(i)["id"] for i in range(sim.plan.players)]))
        ).all()
        assert len(people) == sim.plan.players and all(
            not p.is_test_driver and p.analytics_enabled for p in people
        )
        assert all(
            (db.get(Player, k).display_name, db.get(Player, k).created_at, db.get(Player, k).is_test_driver)
            == v
            for k, v in original.items()
        )
        assert db.scalar(select(func.count()).select_from(AnalysisPerson)) == sim.plan.players
        assert db.scalar(select(func.count()).select_from(RaceStatisticsDay)) > 10
        for wallet in db.scalars(select(CoinWallet)):
            total = db.scalar(
                select(func.sum(StudioCoinEntry.amount)).where(StudioCoinEntry.player_id == wallet.player_id)
            )
            assert wallet.balance == total and total >= 0
        states = {s for s in db.scalars(select(StudioIncident.state))}
        assert states == {"open", "acknowledged", "recovered", "closed"}
        for run in db.scalars(select(Run).where(Run.player_id.in_([p.id for p in people]))):
            assert 0 <= run.finished_at - run.created_at <= 4
    query = f"?since={sim.plan.first_day * DAY}&until={(sim.plan.anchor // DAY + 1) * DAY}"
    headers = {"Authorization": "Bearer " + "o" * 40}
    response = domain.client.get("/v1/admin/analysis/behaviour" + query, headers=headers)
    assert response.status_code == 200 and response.json()["coverage"]["available"] is True
    assert response.json()["counters"]["race_accepted"] == result["accepted_races"]
    for path in ["finance", "incidents", "jobs", "releases", "experiments", "cases", "race-statistics"]:
        assert domain.client.get("/v1/admin/" + path + query, headers=headers).status_code == 200, path
    from bmt_backend.studio_simulator_tick import tick

    opted_out = sim.plan.person(0)["id"]
    with domain.factory() as db:
        db.get(Player, opted_out).analytics_enabled = False
        db.commit()
    at = now() - 3
    refreshed = tick(domain.factory, domain.app.state.settings, sim.plan.dataset, at=at)
    duplicate = tick(domain.factory, domain.app.state.settings, sim.plan.dataset, at=at)
    assert refreshed["inserted_events"] > 0 and duplicate["inserted_events"] == 0
    with domain.factory() as db:
        from bmt_backend.studio_platform_models import StudioObservation
        from bmt_backend.telemetry_models import ProductEvent

        session = identity(sim.plan.dataset, "live-session", refreshed["bucket"], opted_out)
        assert not db.scalar(select(ProductEvent.id).where(ProductEvent.session_id == session))
        observed = db.scalar(select(StudioObservation).order_by(StudioObservation.observed_at.desc()))
        assert observed.observed_at == at
    before = counts(domain)
    again = Simulator(domain.factory, domain.app.state.settings, sim.plan).history(
        progress=lambda *_args, **_kwargs: None
    )
    assert again["complete"] and counts(domain) == before


def test_resume_keeps_templates_and_atomic_cursor_without_double_counting(domain):  # noqa: F811
    sim = prepared(domain)
    first = sim.history(stop_after=3, progress=lambda *_args, **_kwargs: None)
    assert first["cursor"] == 3 and not first["complete"]
    with domain.factory() as db:
        recorded = db.get(OperationState, sim.key).details["templates"]
    resumed = Simulator(domain.factory, domain.app.state.settings, sim.plan)
    second = resumed.history(progress=lambda *_args, **_kwargs: None)
    assert resumed.templates == recorded and second["complete"]
    with pytest.raises(ValueError):
        Simulator(domain.factory, domain.app.state.settings, replace(sim.plan, seed=9)).initialise()
