"""User naming boundaries, evasion, harmless names and publication side effects."""
import secrets

import pytest
from sqlalchemy import func, select
from test_browser_auth import browser as browser_fixture
from test_browser_auth import complete as complete_browser
from test_browser_auth import start as start_browser
from test_challenges import setup
from test_domains import domain as domain_fixture
from test_domains import headers
from test_publication_intents import body
from test_publication_intents import publications as publications_fixture
from test_rivalry import seed

from bmt_backend.challenge_models import Challenge
from bmt_backend.commerce_models import Entitlements, PublicationSlot
from bmt_backend.identity_models import BrowserLogin, Player
from bmt_backend.publication_models import PublicationIntent, PublicationUpload
from bmt_backend.publications import process_one
from bmt_backend.track_models import Track, TrackVersion

domain = domain_fixture
publications = publications_fixture
browser = browser_fixture


@pytest.mark.parametrize("name", [
    "fuck", "FuckRacer", "f.u.c.k", "f u c k", "f_u_c_kRacer", "fu--ck",
    "fuuuuuck", "ffuucckk", "ＦＵＣＫ", "f\u200buck", "f\u2060uck", "f\u034fuck",
    "fυck", "fսck", "f*ck", "f**k", "f**kRacer", "F*CKDickinson", "Racer_sh*t77",
    "c*ntRacer", "b*tchRacer", "n*ggerRacer", "sh!t", "sh1t", "sh111t", "sh-it",
    "shit123", "123shit", "c_u_n_t", "cunt", "cunt99", "b1tch", "b!tch",
    "asshole", "ass", "faggot", "shemale", "white power", "white_power",
    "V1TTU circuit", "v111ttuuu", "vitunrata", "paska-rata", "KUSIPÄÄ", "kÿrpä", "perkele",
    "saatana", "helvetti", "scheiße", "scheisse", "putain", "connard",
    "merde", "mierda", "caralho", "kurwa", "сука", "блядь", "操你妈", "赛道操你妈",
    "まんこ", "くそ", "كس", "wtf", "dickhead", "p.o.r.n", "p0rn", "pr0n",
])
def test_offensive_names_and_common_disguises(name):
    from bmt_backend.name_moderation import contains_profanity
    assert contains_profanity(name)


@pytest.mark.parametrize("name", [
    "Alice", "Bob", "Carol", "Beat my track", "Creator", "Racer", "Class Act",
    "Classic", "Passage", "Scunthorpe", "Scunthorpe Circuit", "Dickinson", "Dick",
    "Cockpit", "Cockburn", "Middlesex", "Sussex", "Essex", "Assen", "Bass Lake",
    "Scunthorpe99", "Dickinson123", "Pen Island", "Yoshitaka", "Takeshita",
    "Hardcore Racing", "Domination", "Ford Escort", "Con Amigos", "Concha",
    "Fanny", "Randy", "Willy", "Gay Racer", "Lesbian Racer", "Queer Racing",
    "Trans Racer", "Homosexual", "Muna", "Pipari", "Viiksi", "Tavara", "Reikä",
    "Panna", "Jätkä", "Pistää", "Mäkelä", "Äänekoski", "Hyvää päivää",
    "Mikko Virtanen", "Björk", "Søren", "Straße", "Speedway 01", "Formula1",
    "A1 Racer", "Route 66", "Track 420", "Anna-Maria", "O'Connor", "A & B",
    "東京サーキット", "中国赛道", "山田太郎", "علي", "Александр", "Night 🏁 Race",
    "XX Racer", "Jelly Donut", "Suklaaosasto", "Alfred", "S h o r t", "Niger", "Nigeria",
    "Jasmine", "Smallville", "Smith", "Grassmaster", "Transmission", "Wismer", "Ismael", "Kosmos",
    "Racing Fan", "Ami", "Del Sol", "Monza 13", "Pots", "Speed 3P",
])
def test_harmless_names_are_preserved(name):
    from bmt_backend.name_moderation import validate_name
    assert validate_name(name) == name


def test_profile_rejects_disguised_name_without_changing_account(auth_client, sign_in):
    account = sign_in()
    auth = {"Authorization": "Bearer " + account["access_token"]}
    response = auth_client.patch("/v1/me", json={"display_name": "f.u.c.k_Racer"}, headers=auth)
    assert response.status_code == 422
    assert "Please choose another name" in response.json()["detail"]
    assert auth_client.get("/v1/me", headers=auth).json()["display_name"] == "alice"


@pytest.mark.parametrize("field", ["name", "document"])
def test_publication_rejects_names_before_storage_or_reservation(publications, field):
    d = publications
    content = body(d)
    if field == "name":
        content["name"] = "V1TTU circuit"
    else:
        content["document"]["name"] = "V1TTU circuit"
    before = sorted(path for path in d.app.state.blobs.root.rglob("*") if path.is_file())
    response = d.client.post("/v1/publications", json=content, headers=headers(d))
    assert response.status_code == 422
    assert "Please choose another name" in response.json()["detail"]
    assert sorted(path for path in d.app.state.blobs.root.rglob("*") if path.is_file()) == before
    with d.factory() as session:
        assert session.scalar(select(func.count()).select_from(PublicationIntent)) == 0
        assert session.scalar(select(func.count()).select_from(PublicationUpload)) == 0


@pytest.mark.parametrize("field", ["player", "track"])
def test_challenge_rejects_legacy_names_used_in_its_generated_title(domain, field):
    d = domain
    version = setup(d)
    with d.factory() as session:
        if field == "player":
            session.get(Player, d.players["Alice"]).display_name = "FuckRacer"
        else:
            session.get(TrackVersion, version).name = "FuckCircuit"
        session.commit()
    response = d.client.post("/v1/challenges", json={"version_id": version,
        "vehicle_id": "compact", "mode": "group"}, headers=headers(d, "Alice"))
    assert response.status_code == 422
    assert "Please choose another name" in response.json()["detail"]
    with d.factory() as session:
        assert session.scalar(select(func.count()).select_from(Challenge)) == 0


@pytest.mark.parametrize("path,extra", [
    ("/v1/auth/google", {"id_token": "x" * 32, "challenge_id": "x" * 36}),
    ("/v1/auth/google/browser/start", {}),
    ("/v1/auth/development", {"subject": "name-fixture"}),
])
def test_every_signup_entry_rejects_the_same_name(auth_client, path, extra):
    response = auth_client.post(path, json={"display_name": "Sh1t", **extra})
    assert response.status_code == 422
    assert "NAME_NOT_ALLOWED" in response.json()["detail"]
    assert "Sh1t" not in response.text and "x" * 32 not in response.text


def test_correcting_a_rejected_google_name_preserves_the_login_challenge(auth_app, auth_client):
    challenge = auth_client.post("/v1/auth/google/challenge").json()
    token = secrets.token_urlsafe(32)
    auth_app.state.identity_verifier.claims[token] = {"sub": "name-fixture", "nonce": challenge["nonce"]}
    content = {"id_token": token, "challenge_id": challenge["challenge_id"], "display_name": "FuckRacer"}
    assert auth_client.post("/v1/auth/google", json=content).status_code == 422
    response = auth_client.post("/v1/auth/google", json={**content, "display_name": "Safe racer"})
    assert response.status_code == 200, response.text
    assert response.json()["player"]["display_name"] == "Safe racer"


def test_new_publication_rejects_legacy_creator_name(publications):
    d = publications
    with d.factory() as session:
        session.get(Player, d.players["Creator"]).display_name = "FuckRacer"
        session.commit()
    response = d.client.post("/v1/publications", json=body(d), headers=headers(d))
    assert response.status_code == 422
    assert d.proof_calls == []
    with d.factory() as session:
        assert session.scalar(select(func.count()).select_from(PublicationIntent)) == 0


@pytest.mark.parametrize("field", ["name", "document", "creator", "owner"])
def test_preupdate_queued_publication_cannot_publish_offensive_names(publications, field):
    d = publications
    response = d.client.post("/v1/publications", json=body(d), headers=headers(d))
    assert response.status_code == 202, response.text
    identity = response.json()["publication_id"]
    with d.factory() as session:
        entitlement = session.get(Entitlements, d.players["Creator"])
        slots_before = entitlement.slots if entitlement else 0
        intent = session.get(PublicationIntent, identity)
        if field == "name":
            intent.name = "FuckCircuit"
        elif field == "owner":
            session.get(Player, d.players["Creator"]).display_name = "FuckRacer"
        else:
            document = d.app.state.blobs.get_json(intent.content_hash)
            document["name" if field == "document" else "creator"] = "FuckRacer"
            intent.content_hash = d.app.state.blobs.put_json(document)
        session.commit()
    assert process_one(d.app)
    result = d.client.get(f"/v1/me/publications/{identity}", headers=headers(d)).json()
    assert result["state"] == "failed" and result["failure_code"] == "name_not_allowed"
    assert result["retryable"] is False
    with d.factory() as session:
        assert session.scalar(select(func.count()).select_from(Track)) == 0
        assert session.scalar(select(func.count()).select_from(PublicationSlot)) == 0
        entitlement = session.get(Entitlements, d.players["Creator"])
        assert (entitlement.slots if entitlement else 0) == slots_before


@pytest.mark.parametrize("completed", [False, True])
def test_exact_acknowledged_publication_retry_survives_policy_change(publications, monkeypatch, completed):
    d = publications
    content, auth = body(d), headers(d)
    content["name"] = content["document"]["name"] = "FuckCircuit"
    # Simulate a queued receipt accepted before this policy existed.
    import bmt_backend.name_moderation as moderation
    with monkeypatch.context() as control:
        control.setattr(moderation, "contains_profanity", lambda value: False)
        response = d.client.post("/v1/publications", json=content, headers=auth)
        if completed:
            assert process_one(d.app)
    assert response.status_code == 202, response.text
    again = d.client.post("/v1/publications", json=content, headers=auth)
    assert again.status_code == 202
    assert again.json()["publication_id"] == response.json()["publication_id"]
    assert again.json()["state"] == ("published" if completed else "queued")
    assert d.client.post("/v1/publications", json=content, headers=headers(d)).status_code == 422
    assert process_one(d.app) is (not completed)
    recovered = d.client.post("/v1/publications", json=content, headers=auth)
    assert recovered.json()["failure_code"] == (None if completed else "name_not_allowed")


def test_generated_challenge_title_checks_the_last_of_five_tracks(domain):
    d = domain
    versions = seed(d, 5)
    with d.factory() as session:
        session.get(TrackVersion, versions[-1]).name = "FuckCircuit"
        session.commit()
    response = d.client.post("/v1/challenges", json={"version_id": versions[0],
        "version_ids": versions, "vehicle_id": "compact", "mode": "group"}, headers=headers(d, "Alice"))
    assert response.status_code == 422 and "NAME_NOT_ALLOWED" in response.json()["detail"]
    with d.factory() as session:
        assert session.scalar(select(func.count()).select_from(Challenge)) == 0


def test_challenge_receipt_recovery_survives_a_later_legacy_name_change(domain):
    d = domain
    version = setup(d)
    content = {"version_id": version, "vehicle_id": "compact", "mode": "group"}
    auth = headers(d, "Alice")
    first = d.client.post("/v1/challenges", json=content, headers=auth)
    assert first.status_code == 201, first.text
    with d.factory() as session:
        session.get(TrackVersion, version).name = "FuckCircuit"
        session.commit()
    recovered = d.client.post("/v1/challenges", json=content, headers=auth)
    assert recovered.status_code == 201 and recovered.json() == first.json()
    assert d.client.post("/v1/challenges", json=content, headers=headers(d, "Alice")).status_code == 422


def test_safe_publication_keeps_exact_document_and_overwrites_untrusted_creator(publications):
    d = publications
    content = body(d, name="Mäkelä Speedway", creator="FuckForgedCreator")
    response = d.client.post("/v1/publications", json=content, headers=headers(d))
    assert response.status_code == 202, response.text
    with d.factory() as session:
        intent = session.get(PublicationIntent, response.json()["publication_id"])
        assert intent.name == "Mäkelä Speedway"
        assert d.app.state.blobs.get_json(intent.content_hash) == {**content["document"], "creator": "Creator"}


def test_long_comparison_is_bounded():
    from bmt_backend.name_moderation import contains_profanity
    with pytest.raises(ValueError, match="comparison length"):
        contains_profanity("a" * 513)


def test_dictionary_files_match_attributed_snapshot():
    import hashlib
    import json

    from bmt_backend.name_moderation import DATA
    manifest = json.loads((DATA / "sources.json").read_text(encoding="utf-8"))
    assert manifest["license"] == "CC-BY-4.0"
    for name, source in manifest["sources"].items():
        path = DATA / ("LICENSE.txt" if name == "LICENSE" else name + ".txt")
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source["sha256"]


@pytest.mark.parametrize("name", ["a" * 513, "\ufdfa" * 512])
def test_pathological_embedded_names_are_rejected_without_server_error(publications, name):
    d = publications
    content = body(d)
    content["document"]["name"] = name
    response = d.client.post("/v1/publications", json=content, headers=headers(d))
    assert response.status_code == 422 and response.json()["detail"] == "INVALID_INPUT"


@pytest.mark.parametrize("field", ["name", "title"])
def test_challenges_do_not_accept_unchecked_custom_name_fields(domain, field):
    d = domain
    version = setup(d)
    response = d.client.post("/v1/challenges", json={"version_id": version,
        "vehicle_id": "compact", "mode": "group", field: "FuckCircuit"}, headers=headers(d, "Alice"))
    assert response.status_code == 422


def test_pending_browser_handoff_rechecks_names_saved_before_update(browser):
    client, app = browser
    browser_token, poll_token = start_browser(client, "Safe racer")
    with app.state.session_factory() as session:
        row = session.scalar(select(BrowserLogin))
        row.display_name = "FuckRacer"
        session.commit()
    assert complete_browser(client, app, browser_token).status_code == 200
    result = client.post("/v1/auth/google/browser/poll", json={"token": poll_token})
    assert result.status_code == 422 and "NAME_NOT_ALLOWED" in result.json()["detail"]
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(Player)) == 0


def test_track_content_validator_covers_tools_and_new_revision_names():
    from pydantic import ValidationError

    from bmt_backend.tracks import TrackContent
    with pytest.raises(ValidationError, match="NAME_NOT_ALLOWED"):
        TrackContent(name="FuckCircuit", document={"name": "Safe"})
    with pytest.raises(ValidationError, match="NAME_NOT_ALLOWED"):
        TrackContent(name="Safe", document={"name": "FuckCircuit"})
