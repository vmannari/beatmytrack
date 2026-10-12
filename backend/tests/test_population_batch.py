"""Development-only resets preserve real PBs and persist exactly one job per pair."""
import dataclasses
import socket
import threading
import time

import pytest
import uvicorn
from backend.tools.audit_test_population_batch import audit
from sqlalchemy import select
from test_rivalry_http import seed
from test_test_drivers import KEY, auth, bot_login, fleet
from test_test_drivers import drivers as _drivers
from test_verifier import real_verifier as _real_verifier

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.test_population_batch import ACTIVE, batch_jobs, drive_idle
from bmt_backend.test_population_tool import API
from bmt_backend.track_models import OperationState, PersonalBest, Run, Track
from bmt_backend.worker import process_one

drivers = _drivers
real_verifier = _real_verifier


def submit(drivers, login, version, *, test, verify=True):
    ticket = drivers.client.post("/v1/run-tickets", json={"version_id": version,
        "vehicle_id": "compact", "test_population": test}, headers=auth(login)).json()
    response = drivers.client.post("/v1/runs", json={"ticket_id": ticket["ticket_id"],
        "replay": {"schema": "bmt-replay-v1", "frames": [[0, 166, 0]]*30}}, headers=auth(login))
    assert response.status_code == 202, response.text
    if verify:
        assert process_one(drivers.app)
    return response.json()["run_id"]


def preview(drivers):
    result = drivers.client.get("/v1/dev/test-drivers/batches/preview?vehicle_id=compact",
                               headers={"X-Dev-Auth-Key": KEY})
    assert result.status_code == 200, result.text
    return result.json()


def test_reset_is_test_only_idempotent_and_all_current_tracks_included(drivers):
    first = preview(drivers)
    version = first["tracks"][0]["version_id"]
    # A current community circuit is deliberately not rivalry-eligible.
    with drivers.factory() as session:
        last = session.get(Track, first["tracks"][-1]["track_id"])
        last.official = False
        session.commit()
    population = fleet(drivers, count=2)
    bot = bot_login(drivers, population["profiles"][0])
    real_run = submit(drivers, drivers.login, version, test=False)
    test_run = submit(drivers, bot, version, test=True)
    pending_test = submit(drivers, bot, version, test=True, verify=False)
    pending_real = submit(drivers, drivers.login, version, test=False, verify=False)
    before = preview(drivers)
    assert before["test_records"] == 1 and before["protected_real_records"] == 1
    body = {"seed":20261008,"count":100,"vehicle_id":"compact","clear_test_records":True,
            "inventory_digest":before["inventory_digest"]}
    response = drivers.client.post("/v1/dev/test-drivers/batches", json=body, headers={"X-Dev-Auth-Key": KEY})
    assert response.status_code == 200, response.text
    result = response.json()
    assert result["driver_count"] == 100 and result["track_count"] == len(before["tracks"])
    assert result["expected_jobs"] == 100*len(before["tracks"]) and result["cleared_test_records"] == 1
    after = preview(drivers)
    assert after["test_records"] == 0 and after["protected_real_digest"] == before["protected_real_digest"]
    with drivers.factory() as session:
        assert session.scalar(select(PersonalBest).where(PersonalBest.run_id == real_run))
        assert session.scalar(select(PersonalBest).where(PersonalBest.run_id == test_run)) is None
        assert session.get(Run, test_run) is not None  # Raw audited history is retained.
        fenced = session.get(Run, pending_test)
        assert fenced.status == "failed" and fenced.failure_code == "test_records_reset"
        assert session.get(Run, pending_real).status == "queued"
        jobs = batch_jobs(session, result["batch_id"])
        assert len(jobs) == result["expected_jobs"]
        assert len({(j.details["player_id"], j.details["version_id"]) for j in jobs}) == len(jobs)
        assert len({j.details["player_id"] for j in jobs}) == 100
    again = drivers.client.post("/v1/dev/test-drivers/batches", json=body, headers={"X-Dev-Auth-Key": KEY})
    assert again.json() == result
    assert drivers.client.get("/v1/dev/test-drivers/batches/"+result["batch_id"]).status_code == 401
    assert not drive_idle(drivers.app)  # No native engine cannot invent a result.


def test_stale_inventory_and_disabled_gate_never_reset_data(drivers):
    before = preview(drivers)
    bad = drivers.client.post("/v1/dev/test-drivers/batches", json={"seed":99,"count":100,
        "inventory_digest":"0"*64}, headers={"X-Dev-Auth-Key": KEY})
    assert bad.status_code == 409
    drivers.app.state.settings = dataclasses.replace(drivers.app.state.settings, test_drivers_enabled=False)
    denied = drivers.client.post("/v1/dev/test-drivers/batches", json={"seed":99,"count":100,
        "inventory_digest":before["inventory_digest"]}, headers={"X-Dev-Auth-Key": KEY})
    assert denied.status_code == 404
    with drivers.factory() as session:
        assert session.get(OperationState, ACTIVE) is None
    assert not drive_idle(drivers.app)


def test_new_generation_reuses_players_and_preserves_existing_best_rows(drivers):
    before = preview(drivers)
    body = {"seed":41008,"count":2,"clear_test_records":False,
            "inventory_digest":before["inventory_digest"]}
    first = drivers.client.post("/v1/dev/test-drivers/batches",json=body,
                                headers={"X-Dev-Auth-Key":KEY}).json()
    with drivers.factory() as session:
        first_jobs = batch_jobs(session,first["batch_id"])
        players = {j.details["player_id"] for j in first_jobs}
        guard = session.get(OperationState,ACTIVE)
        guard.details = {**guard.details,"status":"complete"}
        session.commit()
    population = fleet(drivers,seed_value=41008,count=2,low=0.0,high=1.0)
    login = bot_login(drivers,population["profiles"][0])
    run = submit(drivers,login,before["tracks"][0]["version_id"],test=True)
    inventory = preview(drivers)
    body.update(generation=1,inventory_digest=inventory["inventory_digest"])
    response = drivers.client.post("/v1/dev/test-drivers/batches",json=body,
                                   headers={"X-Dev-Auth-Key":KEY})
    assert response.status_code == 200,response.text
    second = response.json()
    assert second["batch_id"] != first["batch_id"] and second["cleared_test_records"] == 0
    with drivers.factory() as session:
        assert {j.details["player_id"] for j in batch_jobs(session,second["batch_id"])} == players
        assert session.scalar(select(PersonalBest).where(PersonalBest.run_id==run)) is not None
    retry = drivers.client.post("/v1/dev/test-drivers/batches",json=body,headers={"X-Dev-Auth-Key":KEY})
    assert retry.json() == second


@pytest.mark.godot
def test_batch_generates_real_five_lap_proofs_and_survives_app_restart(tmp_path, real_verifier):
    listener = socket.socket(); listener.bind(("127.0.0.1",0))
    url = f"http://127.0.0.1:{listener.getsockname()[1]}"
    settings = Settings(environment="development", dev_auth_enabled=True, test_drivers_enabled=True,
        allow_sync_track_validation=True, dev_auth_key=KEY, public_base_url=url,
        database_url=f"sqlite:///{(tmp_path/'batch.sqlite').as_posix()}", object_dir=str(tmp_path/'objects'),
        godot_bin=real_verifier.binary, game_project=str(real_verifier.project),
        auth_limit_per_minute=1000, write_limit_per_minute=1000)
    app = create_app(settings); upgrade(app.state.engine); seed(app)
    server = uvicorn.Server(uvicorn.Config(app,log_level="error",access_log=False))
    thread = threading.Thread(target=server.run,kwargs={"sockets":[listener]},daemon=True);thread.start()
    try:
        for _ in range(100):
            if server.started:break
            time.sleep(.05)
        api = API(url,KEY)
        inventory = api.call("GET","/dev/test-drivers/batches/preview?vehicle_id=compact",operator=True)
        created = api.call("POST","/dev/test-drivers/batches",{"seed":991,"count":2,
            "inventory_digest":inventory["inventory_digest"]},operator=True)
        assert created["expected_jobs"]==10
        for _ in range(40):
            process_one(app)
            view=api.call("GET","/dev/test-drivers/batches/"+created["batch_id"],operator=True)
            if view["complete"]:break
        assert view["complete"] and all(t["verified_players"]==2 for t in view["tracks"])
        report = audit(app, created["batch_id"])
        assert report["verified_runs"] == report["verified_personal_bests"] == 10
        assert all(t["personal_bests"] == 2 for t in report["tracks"])
        with app.state.session_factory() as session:
            runs=session.scalars(select(Run)).all()
            assert len(runs)==10 and all(r.status=="verified" and len(r.lap_ticks)==5 for r in runs)
        # A new app/worker instance loads authoritative progress, never repeats uploads.
        restarted=create_app(settings)
        assert not drive_idle(restarted)
        with restarted.state.session_factory() as session:
            assert len(session.scalars(select(Run)).all())==10
        restarted.state.verifier.close();restarted.state.engine.dispose()
    finally:
        server.should_exit=True;thread.join(timeout=10);listener.close()
        app.state.verifier.close();app.state.engine.dispose()
