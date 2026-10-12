"""Evidence inspection cannot invent timing, cross account links or reveal secrets."""

from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import func, select, text
from test_auth_postgres import postgres_auth  # noqa: F401

from bmt_backend.commerce_models import Entitlements
from bmt_backend.identity_models import Identity, Player
from bmt_backend.resume_models import ResumeRace, ResumeReceipt, ResumeWallet
from bmt_backend.track_models import Board, PersonalBest, Run, RunTicket, Track, TrackVersion, digest


def headers(role="analyst"):
    return {"Authorization": "Bearer " + ("o" if role == "owner" else "a") * 40}


@pytest.fixture
def evidence(auth_app, auth_client, monkeypatch):
    auth_app.state.settings = replace(auth_app.state.settings, admin_owner_key="o" * 40, admin_analyst_key="a" * 40)
    monkeypatch.setattr("bmt_backend.studio.now", lambda: 2000000000)
    with auth_app.state.session_factory() as session:
        player, other = Player(display_name="<script>Racer</script>"), Player(display_name="Other racer")
        session.add_all((player, other))
        session.flush()
        session.add(Identity(player_id=player.id, provider="google", subject="private-provider-subject"))
        track = Track(owner_id=player.id)
        session.add(track)
        session.flush()
        version = TrackVersion(track_id=track.id, number=1, name="Original version", content_hash="a" * 64,
            manifest={"tick_rate": 240}, state="published")
        session.add(version)
        session.flush()
        newer = TrackVersion(track_id=track.id, number=2, name="Newer version", content_hash="b" * 64,
            manifest={"tick_rate": 120}, state="published")
        session.add(newer)
        board = Board(id="c" * 64, version_id=version.id, vehicle_id="compact", manifest={
            "tick_rate": 240, "laps": 5, "physics_version": "historical-physics", "config_hash": "d" * 64,
            "access_token": "private-manifest-secret", "unexpected": {"refresh_token": "private-nested-secret"}})
        session.add(board)
        session.flush()
        ticket = RunTicket(player_id=player.id, board_id=board.id, created_at=100, expires_at=1000)
        other_ticket = RunTicket(player_id=other.id, board_id=board.id, created_at=50, expires_at=2000)
        session.add_all((ticket, other_ticket))
        session.flush()
        run = Run(ticket_id=ticket.id, player_id=player.id, board_id=board.id, replay_hash="e" * 64,
            ghost_hash="f" * 64, status="verified", created_at=200, finished_at=300, time_ticks=24000,
            lap_ticks=[4800] * 5, attempts=2, lease_token="private-worker-lease")
        session.add(run)
        session.flush()
        session.add(PersonalBest(board_id=board.id, player_id=player.id, run_id=run.id, time_ticks=24000))
        resume = ResumeRace(player_id=player.id, ticket_id=ticket.id, expires_at=1000)
        other_resume = ResumeRace(player_id=other.id, ticket_id=other_ticket.id, expires_at=1000)
        session.add_all((resume, other_resume))
        session.flush()
        session.add(ResumeReceipt(race_id=resume.id, ordinal=1, source="daily", input_offset=1200,
            from_tick=1200, to_tick=1000, created_at=150))
        private_receipt = ResumeReceipt(race_id=other_resume.id, ordinal=1, source="balance", input_offset=1200,
            from_tick=1200, to_tick=1000, created_at=150)
        session.add(private_receipt)
        session.commit()
        ids = {"run": run.id, "player": player.id, "other": other.id, "version": version.id,
            "ticket": ticket.id, "resume": resume.id, "private_receipt": private_receipt.id}

    def forbidden(*args, **kwargs):
        raise AssertionError("Inspection must not fetch a replay or invoke verification")

    monkeypatch.setattr(auth_app.state.blobs, "get_json", forbidden)
    monkeypatch.setattr(auth_app.state.verifier, "manifest", forbidden)
    return auth_client, auth_app, ids


def test_studio_authentication_and_read_only_capabilities(evidence):
    client, _app, ids = evidence
    for path in ("capabilities", "races/" + ids["run"]):
        for credentials in ({}, {"Authorization": "Bearer game-session"}):
            assert client.get("/v1/admin/studio/" + path, headers=credentials).status_code == 401
        for role in ("analyst", "owner"):
            assert client.get("/v1/admin/studio/" + path, headers=headers(role)).status_code == 200
        assert client.post("/v1/admin/studio/" + path, headers=headers("owner")).status_code == 405
    data = client.get("/v1/admin/studio/capabilities", headers=headers()).json()
    assert data["schema"] == "bmt-studio-capabilities-v1" and data["read_only"] is True
    states = {source["key"]: source["status"] for source in data["sources"]}
    assert states["race_evidence"] == "supported"
    assert states["behaviour"] == states["client_quality"] == states["provider_commerce"] == "unavailable"
    assert states["player_support"] == states["race_bundle"] == "partial"


def test_race_contract_timing_links_and_redaction(evidence):
    client, app, ids = evidence
    response = client.get("/v1/admin/studio/races/" + ids["run"], headers=headers())
    assert response.status_code == 200 and response.headers["cache-control"] == "no-store"
    data = response.json()
    assert data["contract"]["version_id"] == ids["version"]
    assert data["contract"]["track_name"] == "Original version"
    assert data["contract"]["manifest"]["physics_version"] == "historical-physics"
    assert data["timing"] == {"accepted": True, "tick_hz": 240, "time_ticks": 24000,
        "lap_ticks": [4800] * 5, "time_seconds": 100, "lap_seconds": [20] * 5}
    assert data["personal_best"] == {"current": True}
    assert data["ticket"] == {"id": ids["ticket"], "issued_at": 100, "expires_at": 1000}
    assert [(entry["event"], entry["at"]) for entry in data["lifecycle"]] == [
        ("ticket_issued", 100), ("submission_received", 200), ("verification_verified", 300)]
    assert "not the driving finish time" in data["lifecycle"][-1]["description"]
    assert data["run"]["verification_terminal_at"] == 300
    assert data["player"]["is_test_driver"] is False
    assert data["resumes"]["total"] == 1 and len(data["resumes"]["items"]) == 1
    assert ids["private_receipt"] not in response.text
    for secret in ("private-provider-subject", "private-worker-lease", "private-manifest-secret",
                   "private-nested-secret", "lease_token", "refresh_token", "access_token"):
        assert secret not in response.text
    assert "request_trace" in {row["key"] for row in data["coverage"] if row["status"] == "unavailable"}
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(ResumeWallet)) == 0
        assert session.scalar(select(func.count()).select_from(Entitlements)) == 0


@pytest.mark.parametrize("artificial", [False, True])
def test_race_player_type_uses_authoritative_flag_without_provider_inference(evidence, artificial):
    client, app, ids = evidence
    with app.state.session_factory() as session:
        session.get(Player, ids["player"]).is_test_driver = artificial
        session.scalar(select(Identity).where(Identity.player_id == ids["player"])).provider = "development"
        session.commit()
    data = client.get("/v1/admin/studio/races/" + ids["run"], headers=headers()).json()
    assert data["player"]["is_test_driver"] is artificial
    assert data["timing"]["accepted"] is True


@pytest.mark.parametrize("tick_rate", [None, 0, "120", 120.0, True, 1001])
def test_missing_or_invalid_pinned_tick_rate_never_uses_live_defaults(evidence, tick_rate):
    client, app, ids = evidence
    with app.state.session_factory() as session:
        board = session.get(Board, "c" * 64)
        board.manifest = {"tick_rate": tick_rate}
        session.commit()
    data = client.get("/v1/admin/studio/races/" + ids["run"], headers=headers()).json()
    assert data["timing"]["tick_hz"] is None
    assert data["timing"]["time_ticks"] == 24000
    assert data["timing"]["time_seconds"] is data["timing"]["lap_seconds"] is None


@pytest.mark.parametrize("status", ["queued", "verifying", "rejected", "failed"])
def test_unaccepted_time_never_presented_as_verified_and_missing_phases_are_honest(evidence, status):
    client, app, ids = evidence
    with app.state.session_factory() as session:
        run = session.get(Run, ids["run"])
        run.status = status
        run.finished_at = None if status in ("queued", "verifying") else 300
        session.commit()
    data = client.get("/v1/admin/studio/races/" + ids["run"], headers=headers()).json()
    assert data["timing"]["accepted"] is False
    for field in ("time_ticks", "lap_ticks", "time_seconds", "lap_seconds"):
        assert data["timing"][field] is None
    assert len(data["lifecycle"]) == (2 if status in ("queued", "verifying") else 3)
    assert not any(row["event"] in ("client_race_started", "client_race_finished", "verification_started") for row in data["lifecycle"])


def test_bundle_checksum_attachment_and_unknown_ids(evidence):
    client, _app, ids = evidence
    path = "/v1/admin/studio/races/" + ids["run"]
    data = client.get(path, headers=headers()).json()
    response = client.get(path + "?download=true", headers=headers())
    assert response.json() == data
    assert response.headers["content-disposition"] == f'attachment; filename="race-{ids["run"]}-evidence.json"'
    checksum = data.pop("checksum")
    assert checksum == digest(data)
    assert client.get("/v1/admin/studio/races/" + str(uuid4()), headers=headers()).status_code == 404
    assert client.get("/v1/admin/studio/races/not-an-id", headers=headers()).status_code == 422


def test_mismatched_ticket_and_resume_links_are_not_exposed(evidence):
    client, app, ids = evidence
    with app.state.session_factory() as session:
        session.get(RunTicket, ids["ticket"]).player_id = ids["other"]
        session.get(ResumeRace, ids["resume"]).player_id = ids["other"]
        session.commit()
    data = client.get("/v1/admin/studio/races/" + ids["run"], headers=headers()).json()
    assert data["ticket"] is None
    assert data["resumes"]["total"] == 0 and data["resumes"]["items"] == []
    assert data["lifecycle"][0]["event"] == "submission_received"


def test_receipt_inspection_is_bounded_even_for_invalid_oversized_history(evidence):
    client, app, ids = evidence
    with app.state.session_factory() as session:
        session.add_all(ResumeReceipt(race_id=ids["resume"], ordinal=index, source="daily",
            input_offset=1200, from_tick=1200, to_tick=1000) for index in range(2, 104))
        session.commit()
    data = client.get("/v1/admin/studio/races/" + ids["run"], headers=headers()).json()
    assert data["resumes"]["total"] == 103
    assert data["resumes"]["limit"] == 100 and len(data["resumes"]["items"]) == 100


@pytest.mark.postgres
def test_postgres_snapshot_is_read_only_and_does_not_mix_worker_completion(postgres_auth, monkeypatch):  # noqa: F811
    from bmt_backend import studio

    app, client = postgres_auth
    app.state.settings = replace(app.state.settings, admin_analyst_key="a" * 40)
    monkeypatch.setattr(studio, "now", lambda: 2000000000)
    with app.state.session_factory() as session:
        player = Player(display_name="Snapshot racer")
        session.add(player)
        session.flush()
        track = Track(owner_id=player.id)
        session.add(track)
        session.flush()
        version = TrackVersion(track_id=track.id, number=1, name="Snapshot track", content_hash="a" * 64,
            manifest={"tick_rate": 240}, state="published")
        session.add(version)
        session.flush()
        board = Board(id="c" * 64, version_id=version.id, vehicle_id="compact", manifest={"tick_rate": 240, "laps": 5})
        session.add(board)
        session.flush()
        ticket = RunTicket(player_id=player.id, board_id=board.id, created_at=100, expires_at=1000)
        session.add(ticket)
        session.flush()
        run = Run(ticket_id=ticket.id, player_id=player.id, board_id=board.id, replay_hash="e" * 64,
            status="queued", created_at=200)
        session.add(run)
        session.commit()
        run_id, player_id = run.id, player.id

    original = studio.race_evidence
    observed = []

    def finish_between_reads(session, identity):
        assert session.scalar(text("SHOW transaction_read_only")) == "on"
        assert session.scalar(text("SHOW transaction_isolation")) == "repeatable read"
        captured = session.get(Run, identity)
        observed.append(captured.status)
        if len(observed) == 1:
            with app.state.session_factory() as worker:
                completed = worker.get(Run, identity)
                completed.status, completed.finished_at = "verified", 300
                completed.time_ticks, completed.lap_ticks = 24000, [4800] * 5
                worker.add(PersonalBest(board_id=completed.board_id, player_id=player_id,
                    run_id=identity, time_ticks=24000))
                worker.commit()
        return original(session, identity)

    monkeypatch.setattr(studio, "race_evidence", finish_between_reads)
    response = client.get("/v1/admin/studio/races/" + run_id, headers=headers())
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["run"]["status"] == "queued" and data["timing"]["accepted"] is False
    assert data["personal_best"]["current"] is False
    response = client.get("/v1/admin/studio/races/" + run_id + "?download=true", headers=headers())
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["run"]["status"] == "verified" and data["personal_best"]["current"] is True
    assert data["timing"]["time_seconds"] == 100
    assert "attachment" in response.headers["content-disposition"]
    assert data.pop("checksum") == digest(data)
    assert observed == ["queued", "verified"]
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(Run)) == 1
        assert session.scalar(select(func.count()).select_from(PersonalBest)) == 1
        assert session.scalar(select(func.count()).select_from(Entitlements)) == 0
        assert session.scalar(select(func.count()).select_from(ResumeWallet)) == 0
