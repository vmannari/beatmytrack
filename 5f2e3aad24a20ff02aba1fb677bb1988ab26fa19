"""Lifecycle/delivery regressions from the November telemetry review."""
# ruff: noqa: F811
import json
import logging
from dataclasses import replace
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

import pytest
from alembic import command
from sqlalchemy import create_engine, func, inspect, select
from test_product_analytics import AT, body, observed, product, report  # noqa: F401

from bmt_backend.migrate import configuration, upgrade
from bmt_backend.observability import JsonFormatter
from bmt_backend.product_analytics import project_pending
from bmt_backend.telemetry_models import ProductLossSource, ProductProfile

FIXTURE = Path(__file__).with_name("fixtures") / "telemetry_utf8_batch.json"


def loss(product, count, *, install=None, counter=None, identifier=None):
    app, client, headers, _player = product
    props = {"dropped_events": count}
    if counter:
        props["counter_id"] = counter
    event = observed("collection_summary", properties=props,
                     session_id="00000000-0000-4000-8000-000000000001")
    if identifier:
        event["id"] = identifier
    packet = {**body([event]), "install_id": install}
    result = client.post("/v1/telemetry/batches", json=packet, headers=headers)
    assert result.status_code == 200, result.text
    project_pending(app.state.session_factory, at=AT)
    return result.json()["events"][0]


def test_independent_installations_restarts_and_out_of_order_loss_snapshots(product):
    first, second = str(uuid4()), str(uuid4())
    assert loss(product, 5, install=first)["status"] == "accepted"
    identifier = str(uuid4())
    assert loss(product, 3, install=second, identifier=identifier)["status"] == "accepted"
    assert loss(product, 3, install=second, identifier=identifier)["status"] == "duplicate"
    loss(product, 2, install=first)  # Late lower snapshot cannot subtract/recount.
    loss(product, 5, install=second)  # Same lifetime survives process restart.
    assert report(product)["quality"]["dropped_events"] == 10


def test_explicit_counter_lifetimes_can_reset_under_the_same_installation(product):
    install = str(uuid4())
    first, second = str(uuid4()), str(uuid4())
    loss(product, 5, install=install, counter=first)
    loss(product, 3, install=install, counter=second)
    loss(product, 1, install=install, counter=first)
    assert report(product)["quality"]["dropped_events"] == 8
    app, _client, _headers, player = product
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(ProductLossSource)) == 2
        assert db.get(ProductLossSource, (player, first)).counters["dropped_events"] == 5


def test_same_source_reference_is_isolated_between_accounts(product, sign_in):
    app, client, _headers, player = product
    source = str(uuid4())
    loss(product, 5, counter=source)
    second = sign_in("second-loss-owner")
    other = (app, client, {"Authorization": "Bearer " + second["access_token"]}, second["player"]["id"])
    loss(other, 3, counter=source)
    loss(product, 6, counter=source)
    assert report(product)["quality"]["dropped_events"] == 9
    with app.state.session_factory() as db:
        assert db.get(ProductLossSource, (player, source)).counters["dropped_events"] == 6
        assert db.get(ProductLossSource, (second["player"]["id"], source)).counters["dropped_events"] == 3


def test_failed_projection_rolls_back_source_watermark_with_metric_effects(product, monkeypatch):
    from bmt_backend import telemetry_projection
    from bmt_backend.telemetry_processing import actor_once
    app, client, headers, _player = product
    event = observed("collection_summary", properties={"counter_id": str(uuid4()), "dropped_events": 5})
    assert client.post("/v1/telemetry/batches", json=body([event]), headers=headers).status_code == 200
    original = telemetry_projection.write_metrics
    def failed(*_args):
        raise RuntimeError("synthetic metric transaction failure")
    monkeypatch.setattr(telemetry_projection, "write_metrics", failed)
    with pytest.raises(RuntimeError, match="synthetic"):
        actor_once(app.state.session_factory, at=AT)
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(ProductLossSource)) == 0
    monkeypatch.setattr(telemetry_projection, "write_metrics", original)
    project_pending(app.state.session_factory, at=AT)
    project_pending(app.state.session_factory, at=AT)
    assert report(product)["quality"]["dropped_events"] == 5


def test_old_projection_maximum_is_claimed_once_without_recounting_history(product):
    app, _client, _headers, player = product
    with app.state.session_factory() as db:
        db.add(ProductProfile(player_id=player, milestones=[], projection={}, truncated=False,
                              quality={"dropped_events": 5}, truncations={}))
        db.commit()
    loss(product, 8, install=str(uuid4()))
    loss(product, 2, install=str(uuid4()))
    assert report(product)["quality"]["dropped_events"] == 5  # 3 new + 2 independent.


def test_shared_unicode_fixture_fits_client_limit_and_backend_accepts_all_rows(product):
    app, client, headers, _player = product
    app.state.settings = replace(app.state.settings, client_quality_enabled=True)
    packet = json.loads(FIXTURE.read_text(encoding="utf-8"))
    wire = json.dumps(packet, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    assert len(wire) < 65536 < len(json.dumps(packet, separators=(",", ":")).encode())
    response = client.post("/v1/telemetry/batches", content=wire,
                           headers={**headers, "Content-Type": "application/json"})
    assert response.status_code == 200, response.text
    assert len(response.json()["events"]) == 50
    assert all(row["status"] == "accepted" for row in response.json()["events"])


def test_counter_id_is_negotiated_and_strictly_validated(product):
    _app, client, headers, _player = product
    assert client.get("/v1/bootstrap").json()["product_telemetry"]["loss_counter_version"] == 2
    for counter in ("private arbitrary text", True, str(uuid4()) + "\n"):
        packet = body([observed("collection_summary", properties={"dropped_events": 1, "counter_id": counter})])
        result = client.post("/v1/telemetry/batches", json=packet, headers=headers)
        assert result.json()["events"][0]["status"] == "rejected"


def test_loss_source_migration_is_additive_and_reversible(tmp_path):
    engine = create_engine("sqlite:///" + str(tmp_path / "migration.sqlite"))
    try:
        previous = "0076_multi_car_world_ranking"
        command.upgrade(configuration(engine), previous)
        player = str(uuid4())
        with engine.begin() as db:
            db.execute(ProductProfile.__table__.insert().values(player_id=player,
                milestones=[["app_first_open", AT]], projection={"retained": 1},
                quality={"dropped_events": 5}, truncated=False, truncations={}))
        upgrade(engine)
        assert {column["name"] for column in inspect(engine).get_columns("product_loss_sources")} == {
            "player_id", "source_id", "counters"}
        command.downgrade(configuration(engine), previous)
        assert "product_loss_sources" not in inspect(engine).get_table_names()
        with engine.connect() as db:
            row = db.execute(select(ProductProfile.quality, ProductProfile.projection,
                                    ProductProfile.milestones).where(ProductProfile.player_id == player)).one()
            assert row.quality == {"dropped_events": 5} and row.projection == {"retained": 1}
            assert row.milestones == [["app_first_open", AT]]
    finally:
        engine.dispose()


def test_loss_sources_are_erased_without_changing_persisted_deletion_stages(product):
    from test_privacy import deletion_body, drain
    app, client, headers, player = product
    loss(product, 2, install=str(uuid4()))
    deleted = client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=headers)
    assert deleted.status_code == 202
    drain(app)
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(ProductLossSource).where(
            ProductLossSource.player_id == player)) == 0


@pytest.mark.parametrize("recorder_fails", [False, True])
def test_worker_entrypoint_logs_safe_stage_owner_and_failure_site(monkeypatch, recorder_fails):
    from bmt_backend import product_worker as worker
    records = []
    class Capture(logging.Handler):
        def emit(self, record):
            records.append(json.loads(JsonFormatter().format(record)))
    namespace = {"__name__": "bmt_backend.telemetry_fixture"}
    exec(compile('def fail(*args, **kwargs):\n    raise ValueError("secret /private/source")\n',  # noqa: S102 - synthetic safe-site fixture
                 "/private/worker.py", "exec"), namespace)
    def fail(*args, **kwargs):
        try:
            namespace["fail"]()
        except ValueError as error:
            error.telemetry_owner = ("actor", [2, 9])
            raise
    def record(*args):
        if recorder_fails:
            raise OSError("secret database URL")
    monkeypatch.setattr("sys.argv", ["product_worker", "--once", "--stage", "actor"])
    monkeypatch.setattr(worker.Settings, "from_env", lambda: worker.Settings(environment="test", telemetry_enabled=True))
    monkeypatch.setattr(worker.signal, "signal", lambda *_: None)
    monkeypatch.setattr(worker, "make_engine", lambda *_: SimpleNamespace(dispose=lambda: None))
    monkeypatch.setattr(worker, "make_session_factory", lambda _: None)
    monkeypatch.setattr(worker.PreparationSchedule, "step", lambda *_: None)
    monkeypatch.setattr(worker, "actor_once", fail)
    monkeypatch.setattr(worker, "record_failure", record)
    handler = Capture()
    log = logging.getLogger("bmt.product")
    log.addHandler(handler)
    try:
        worker.main()
    finally:
        log.removeHandler(handler)
    assert logging.getLogger("bmt").handlers
    first = records[0]
    assert first["event"] == "telemetry_stage_failed"
    assert first["telemetry_stage"] == "actor" and first["telemetry_owners"] == [2, 9]
    assert first["failure_site"] == "bmt_backend.telemetry_fixture:fail:2"
    assert first["exception_type"] == "ValueError"
    assert len(records) == (2 if recorder_fails else 1)
    assert "secret" not in json.dumps(records) and "/private" not in json.dumps(records)
