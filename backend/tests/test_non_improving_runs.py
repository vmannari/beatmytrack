"""NIS01-NIS06: discard only non-improving scores, retaining completion rewards."""
# ruff: noqa: F811 - imported parametrized fixture is intentionally injected by pytest.
import json
import uuid
from pathlib import Path

import pytest
from sqlalchemy import func, select
from test_domains import domain, headers, public_course, race, ticket  # noqa: F401
from test_rivalry import join, rivalry_ticket, seed

from bmt_backend.economy_models import CoinReward, CoinWallet
from bmt_backend.non_improving_runs import candidate
from bmt_backend.rivalry_models import RivalryBest
from bmt_backend.track_models import LapPersonalBest, PersonalBest, QueuePlayer, QueueReservation, Run
from bmt_backend.worker import process_one

GOLDEN = json.loads((Path(__file__).resolve().parents[2] / "game/tests/fixtures/non_improving_run_v1.json").read_text())


def replay(laps=(20, 20, 20, 20, 20), **extra):
    ticks = sum(laps)
    return {"schema":"bmt-trajectory-v1", "input_count":ticks,
            "claimed_lap_ticks":list(laps), "race_proof":{"schema":"bmt-race-path-v1",
                "samples":[[0,0,0,0],[ticks,0,0,0]]}, **extra}


def submit_hint(d, issued, recording=None, player="Alice", key=None):
    return d.client.post("/v1/runs", json={"ticket_id":issued["ticket_id"], "replay":recording or replay()},
                         headers=headers(d, player, key))


def prepared(d):
    version, _board = public_course(d)
    first = race(d, version, "Alice", frames=20)
    return version, first


def forbid_verification(d, monkeypatch):
    def forbidden(*_args, **_kwargs):
        raise AssertionError("Non-improving completion invoked verification")
    monkeypatch.setattr(d.app.state.verifier, "verify_run", forbidden)


@pytest.mark.parametrize("laps", [(20,20,20,20,20), (24,24,24,24,24)])
def test_tied_and_slower_runs_skip_before_queue_and_credit_once(domain, monkeypatch, laps):
    d = domain
    version, first = prepared(d)
    with d.factory() as session:
        opening = session.get(CoinWallet, d.players["Alice"]).balance
    forbid_verification(d, monkeypatch)
    issued, key = ticket(d, version, "Alice"), str(uuid.uuid4())
    response = submit_hint(d, issued, replay(laps), key=key)
    assert response.status_code == 202, response.text
    result = response.json()
    assert {key:result[key] for key in GOLDEN["terminal_fields"]} == GOLDEN["terminal_fields"]
    assert result["status"] == "skipped" and result["skip_reason"] == "no_improvement"
    assert result["poll_after_ms"] == 0 and result["failure_code"] is None and not result["retryable"]
    assert submit_hint(d, issued, replay(laps), key=key).json() == result
    assert submit_hint(d, issued, replay(laps)).json()["run_id"] == result["run_id"]
    paths = ["/v1/runs/"+result["run_id"]+"?completion=true",
             "/v1/runs/"+result["run_id"]+"/wait?timeout_ms=0&completion=true"]
    for path in paths:
        value = d.client.get(path, headers=headers(d,"Alice")).json()
        assert value["status"] == "skipped" and value["completion"]["reward"]["amount"] == 50
    with d.factory() as session:
        run = session.get(Run, result["run_id"])
        assert run.attempts == 0 and run.ghost_hash is None and run.lease_token is None
        assert session.get(PersonalBest, (first["board_id"],d.players["Alice"])).run_id == first["run_id"]
        assert session.get(LapPersonalBest, (first["board_id"],d.players["Alice"])).run_id == first["run_id"]
        assert session.get(CoinWallet, d.players["Alice"]).balance == opening+50
        assert session.scalar(select(func.count()).select_from(CoinReward).where(CoinReward.run_id == run.id)) == 1
        assert session.scalar(select(func.count()).select_from(QueueReservation)) == 0


@pytest.mark.parametrize("laps", [(19,19,19,19,19), (30,19,20,20,21)])
def test_race_or_flying_lap_pb_always_queues_for_verification(domain, laps):
    d = domain
    version, _ = prepared(d)
    result = submit_hint(d, ticket(d, version, "Alice"), replay(laps)).json()
    assert result["status"] == "queued", result
    assert process_one(d.app)
    assert d.client.get("/v1/runs/"+result["run_id"],headers=headers(d,"Alice")).json()["status"] == "verified"


def test_first_result_missing_lap_best_and_old_recordings_still_verify(domain):
    d = domain
    version, first = prepared(d)
    bob = submit_hint(d, ticket(d, version, "Bob"), player="Bob")
    assert bob.status_code == 202 and bob.json()["status"] == "queued"
    with d.factory() as session:
        session.delete(session.get(LapPersonalBest,(first["board_id"],d.players["Alice"])))
        session.commit()
    assert submit_hint(d,ticket(d,version,"Alice")).json()["status"] == "queued"
    old = replay()
    old.pop("claimed_lap_ticks")
    assert submit_hint(d,ticket(d,version,"Alice"),old).json()["status"] == "queued"


@pytest.mark.parametrize("laps", [[], [20]*4, [True,20,20,20,39], [0,20,20,20,40], [20,20,20,20,21]])
def test_malformed_summaries_cannot_skip_or_earn_rewards(domain, laps):
    d = domain
    version, _ = prepared(d)
    body = replay()
    body["claimed_lap_ticks"] = laps
    response = submit_hint(d,ticket(d,version,"Alice"),body)
    assert response.status_code == 422, response.text


def test_missing_trajectory_endpoints_cannot_use_the_skip(domain):
    d = domain
    version, _ = prepared(d)
    body = replay()
    body["race_proof"]["samples"][-1][0] -= 1
    assert candidate(body) is None
    assert submit_hint(d,ticket(d,version,"Alice"),body).json()["status"] == "queued"


def test_full_queue_does_not_block_non_improving_completion(domain, monkeypatch):
    from test_domains import submit
    d = domain
    version, _ = prepared(d)
    for _ in range(8):
        submit(d,ticket(d,version,"Alice"),"Alice")
    forbid_verification(d,monkeypatch)
    response = submit_hint(d,ticket(d,version,"Alice"))
    assert response.status_code == 202 and response.json()["status"] == "skipped", response.text
    with d.factory() as session:
        assert session.get(QueuePlayer,d.players["Alice"]).pending == 8
        assert session.scalar(select(func.count()).select_from(QueueReservation)) == 8


def test_clean_completion_reward_uses_the_existing_incident_report_policy(domain,monkeypatch):
    d = domain
    version, _ = prepared(d)
    forbid_verification(d,monkeypatch)
    body = replay()
    body["race_proof"]["incidents"] = {"schema":"bmt-race-incidents-v1", "ticks":100,
                                         "collision_count":0, "off_track":False}
    issued = ticket(d,version,"Alice")
    assert submit_hint(d,issued,body).json()["status"] == "skipped"
    receipt = d.client.get("/v1/economy/rewards/"+issued["ticket_id"],headers=headers(d,"Alice")).json()
    assert receipt["amount"] == 250
    assert {row["title"] for row in receipt["rows"]} == {"Race completed","Clean race"}


def test_worker_rechecks_queued_results_before_reading_geometry(domain,monkeypatch):
    d = domain
    version, first = prepared(d)
    pending = submit_hint(d,ticket(d,version,"Alice"),replay((19,19,19,19,19))).json()
    assert pending["status"] == "queued"
    # A different accepted race beats this queued candidate on both metrics.
    with d.factory() as session:
        session.get(PersonalBest,(first["board_id"],d.players["Alice"])).time_ticks = 90
        session.get(LapPersonalBest,(first["board_id"],d.players["Alice"])).time_ticks = 18
        session.commit()
    forbid_verification(d,monkeypatch)
    assert process_one(d.app)
    with d.factory() as session:
        run = session.get(Run,pending["run_id"])
        assert run.status == "skipped" and run.attempts == 0
        assert session.scalar(select(func.count()).select_from(QueueReservation)) == 0


def test_weekly_best_is_independent_of_a_faster_global_pb(domain,monkeypatch):
    d = domain
    seed(d)
    group = join(d)["group_id"]
    issued = rivalry_ticket(d,group)
    race(d,{"version_id":issued["version_id"]},"Alice",frames=10)
    # First weekly finish must be verified even though the global PB is faster.
    first = submit_hint(d,issued).json()
    assert first["status"] == "queued"
    assert process_one(d.app)
    faster = submit_hint(d,rivalry_ticket(d,group),replay((19,19,19,19,19))).json()
    assert faster["status"] == "queued"
    assert process_one(d.app)
    with d.factory() as session:
        best = session.get(RivalryBest,(group,d.players["Alice"],0))
        source = best.run_id
    forbid_verification(d,monkeypatch)
    issued = rivalry_ticket(d,group)
    skipped = submit_hint(d,issued).json()
    assert skipped["status"] == "skipped"
    result = d.client.get("/v1/rivalry/tickets/"+issued["ticket_id"]+"/result",headers=headers(d,"Alice")).json()
    assert result["status"] == "skipped" and result["outcome"]["improved"] is False
    assert result["outcome"]["points_delta"] == 0
    with d.factory() as session:
        assert session.get(RivalryBest,(group,d.players["Alice"],0)).run_id == source


def test_candidate_reads_only_endpoints():
    class EndpointsOnly(list):
        def __iter__(self):
            raise AssertionError("Skip scanned the trajectory")
    body = replay()
    body["race_proof"]["samples"] = EndpointsOnly(body["race_proof"]["samples"])
    # Exact built-in containers are required; an unknown container is uncertain.
    assert candidate(body) is None
    ordinary = replay()
    ordinary["race_proof"]["samples"].insert(1, object())
    assert candidate(ordinary) == (100,[20]*5)


def test_challenge_best_is_independent_and_attempt_budget_is_retained(domain,monkeypatch):
    from test_challenges import create, normal_run, setup
    from test_challenges import join as join_challenge

    from bmt_backend.challenge_models import ChallengeMember
    d = domain
    version = setup(d)
    normal_run(d,version,"Alice",frames=30)
    challenge = create(d,version,mode="group",attempt_limit=3)
    code = challenge["code"]
    join_challenge(d,code)
    normal_run(d,version,"Bob",frames=10)

    def issued():
        response = d.client.post(f"/v1/challenges/{code}/tickets",headers=headers(d,"Bob"))
        assert response.status_code == 201, response.text
        return response.json()

    opening = submit_hint(d,issued(),player="Bob").json()
    assert opening["status"] == "queued"
    assert process_one(d.app)
    faster = submit_hint(d,issued(),replay((19,19,19,19,19)),player="Bob").json()
    assert faster["status"] == "queued"
    assert process_one(d.app)
    forbid_verification(d,monkeypatch)
    third = issued()
    value = submit_hint(d,third,player="Bob").json()
    assert value["status"] == "skipped"
    result = d.client.get("/v1/challenge-results/"+third["ticket_id"]+"?compact=true",headers=headers(d,"Bob")).json()
    assert result["status"] == "skipped" and result["outcome"]["improved"] is False
    with d.factory() as session:
        member = session.get(ChallengeMember,(challenge["id"],d.players["Bob"]))
        assert member.attempts_used == 3 and member.run_id == faster["run_id"] and member.time_ticks == 95
    assert d.client.post(f"/v1/challenges/{code}/tickets",headers=headers(d,"Bob")).status_code == 409


def test_series_skip_cannot_replace_stage_or_combined_best_sources(domain,monkeypatch):
    from test_challenge_series import create
    from test_challenges import join as join_challenge
    from test_challenges import normal_run

    from bmt_backend.challenge_models import ChallengeMember, ChallengeStageMember
    d = domain
    versions = seed(d,3)
    response = create(d,versions)
    assert response.status_code == 201, response.text
    challenge = response.json()
    join_challenge(d,challenge["code"])
    for index, version in enumerate(versions):
        normal_run(d,version,"Bob",frames=10)
        issued = d.client.post(f"/v1/challenges/{challenge['code']}/tickets?stage={index}",headers=headers(d,"Bob")).json()
        assert submit_hint(d,issued,player="Bob").json()["status"] == "queued"
        assert process_one(d.app)
    with d.factory() as session:
        prior = session.get(ChallengeMember,(challenge["id"],d.players["Bob"]))
        source = prior.run_id
        stage_source = session.get(ChallengeStageMember,(challenge["id"],0,d.players["Bob"])).run_id
        assert prior.time_ticks == 300
    forbid_verification(d,monkeypatch)
    issued = d.client.post(f"/v1/challenges/{challenge['code']}/tickets?stage=0",headers=headers(d,"Bob")).json()
    assert submit_hint(d,issued,player="Bob").json()["status"] == "skipped"
    with d.factory() as session:
        own = session.get(ChallengeMember,(challenge["id"],d.players["Bob"]))
        stage = session.get(ChallengeStageMember,(challenge["id"],0,d.players["Bob"]))
        assert (own.time_ticks,own.run_id) == (300,source)
        assert stage.time_ticks == 100 and stage.run_id == stage_source and stage.attempts_used == 2


def test_expired_foreign_and_unauthorized_rewind_hints_cannot_skip(domain):
    from bmt_backend.track_models import RunTicket, now
    d = domain
    version, _ = prepared(d)
    issued = ticket(d,version,"Alice")
    assert submit_hint(d,issued,player="Bob").status_code == 404
    with d.factory() as session:
        session.get(RunTicket,issued["ticket_id"]).expires_at = now()-1
        session.commit()
    assert submit_hint(d,issued).status_code == 410
    issued = ticket(d,version,"Alice")
    body = replay(input_count=110,rewinds=[{"receipt_id":str(uuid.uuid4()),"input_offset":50,"from_tick":50,"to_tick":40}])
    assert submit_hint(d,issued,body).status_code == 422


def test_skipped_rewind_settles_the_existing_authorized_receipt_once(domain,monkeypatch):
    from test_resumes import begin, spend

    from bmt_backend.resume_models import ResumeReceipt
    d = domain
    version, _ = public_course(d)
    issued = ticket(d,version,"Creator")
    race_id = begin(d,issued["ticket_id"])
    receipt = spend(d,race_id,offset=50,source=50,target=40)
    assert receipt.status_code == 200, receipt.text
    event = {"receipt_id":receipt.json()["receipt_id"],"input_offset":50,"from_tick":50,"to_tick":40}
    body = replay((60,60,60,60,60),input_count=310,rewinds=[event])
    forbid_verification(d,monkeypatch)
    response = submit_hint(d,issued,body,player="Creator")
    assert response.status_code == 202 and response.json()["status"] == "skipped", response.text
    assert response.json()["time_ticks"] == 300
    with d.factory() as session:
        assert session.get(ResumeReceipt,event["receipt_id"]).settled


@pytest.mark.parametrize("restriction,expected", [("disabled",401),("is_test_driver",403)])
def test_account_changes_during_storage_cannot_enter_the_skip(domain,monkeypatch,restriction,expected):
    from bmt_backend.identity_models import Player
    d = domain
    version, _ = prepared(d)
    issued = ticket(d,version,"Alice")
    original = d.app.state.blobs.put_json

    def store_then_restrict(body):
        value = original(body)
        with d.factory() as session:
            setattr(session.get(Player,d.players["Alice"]),restriction,True)
            session.commit()
        return value

    monkeypatch.setattr(d.app.state.blobs,"put_json",store_then_restrict)
    assert submit_hint(d,issued).status_code == expected
    with d.factory() as session:
        assert session.scalar(select(Run.id).where(Run.ticket_id == issued["ticket_id"])) is None


def test_skipped_history_remains_eligible_for_bounded_retention(domain):
    from bmt_backend.maintenance import retain
    from bmt_backend.track_models import now
    d = domain
    version, _ = prepared(d)
    value = submit_hint(d,ticket(d,version,"Alice")).json()
    assert value["status"] == "skipped"
    with d.factory() as session:
        session.get(Run,value["run_id"]).finished_at = now()-2*86400
        session.commit()
    result = retain(d.factory,d.app.state.blobs,days=1,scan_objects=False)
    assert result["runs"] == 1


@pytest.mark.parametrize("failure_mode", ["none","retry","failed"])
def test_explicit_challenge_reuse_verifies_the_original_and_never_credits_twice(domain,monkeypatch,failure_mode):
    from bmt_backend.track_models import OperationState
    d = domain
    version, first = prepared(d)
    issued = ticket(d,version,"Alice")
    skipped = submit_hint(d,issued).json()
    assert skipped["status"] == "skipped"
    with d.factory() as session:
        opening = session.get(CoinWallet,d.players["Alice"]).balance
    key = str(uuid.uuid4())
    path = "/v1/runs/"+skipped["run_id"]+"/retry"
    requested = d.client.post(path,json={},headers=headers(d,"Alice",key))
    assert requested.status_code == 200 and requested.json()["status"] == "queued", requested.text
    assert d.client.post(path,json={},headers=headers(d,"Alice",key)).json() == requested.json()
    if failure_mode == "failed":
        with d.factory() as session:
            session.get(Run,skipped["run_id"]).attempts = d.app.state.settings.max_job_attempts-1
            session.commit()
    original = d.app.state.verifier.verify_run
    calls = []

    def observed(*args,**kwargs):
        calls.append(True)
        if failure_mode != "none" and len(calls) == 1:
            raise RuntimeError("Temporary verification fixture failure")
        return original(*args,**kwargs)

    monkeypatch.setattr(d.app.state.verifier,"verify_run",observed)
    assert process_one(d.app)
    if failure_mode != "none":
        with d.factory() as session:
            run = session.get(Run,skipped["run_id"])
            assert run.status == ("failed" if failure_mode == "failed" else "queued")
            assert session.get(OperationState,"verify:"+run.id) is not None
            run.lease_until = 0
            session.commit()
        if failure_mode == "failed":
            source = d.client.get(f"/v1/challenges/sources?version_id={version['version_id']}&vehicle_id=compact&ticket_id={issued['ticket_id']}",headers=headers(d,"Alice")).json()
            assert source["retryable"] is True
            assert d.client.post(path,json={},headers=headers(d,"Alice")).json()["status"] == "queued"
        assert process_one(d.app)
    assert len(calls) == (1 if failure_mode == "none" else 2)
    with d.factory() as session:
        run = session.get(Run,skipped["run_id"])
        assert run.status == "verified" and session.get(OperationState,"verify:"+run.id) is None
        assert session.get(CoinWallet,d.players["Alice"]).balance == opening
        assert session.get(PersonalBest,(first["board_id"],d.players["Alice"])).run_id == first["run_id"]
    challenge = d.client.post("/v1/challenges",json={"version_id":version["version_id"],"vehicle_id":"compact",
        "mode":"beat","source_ticket_id":issued["ticket_id"]},headers=headers(d,"Alice"))
    assert challenge.status_code == 201, challenge.text
    from bmt_backend.challenge_models import Challenge
    with d.factory() as session:
        assert session.get(Challenge,challenge.json()["id"]).target_run_id == skipped["run_id"]
