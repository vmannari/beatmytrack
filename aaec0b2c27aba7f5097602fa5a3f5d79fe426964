"""Private Studio sign-in, managed MFA claims and first-login enrollment fences."""

import json
import time
from dataclasses import replace

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.studio_identity import CERTS, StudioIdentityVerifier


def settings(tmp_path):
    return Settings(environment="test", workload_role="admin",
        database_url=f"sqlite:///{(tmp_path / 'studio.sqlite').as_posix()}",
        object_dir=str(tmp_path / "objects"), studio_staff_audiences=("staff-project",),
        studio_staff_subjects=json.dumps({"google-owner": {"name": "Owner", "role": "owner"}}),
        studio_identity_project="staff-project", studio_identity_tenant="studio-tenant",
        studio_identity_api_key="public-browser-key", studio_identity_auth_domain="staff-project.firebaseapp.com")


def claims(**updates):
    value = {"iss": "https://securetoken.google.com/staff-project", "aud": "staff-project",
        "sub": "firebase-user", "auth_time": int(time.time()), "email_verified": True,
        "firebase": {"tenant": "studio-tenant", "sign_in_provider": "google.com",
            "identities": {"google.com": ["google-owner"]},
            "sign_in_second_factor": "totp", "second_factor_identifier": "authenticator"}}
    value.update(updates)
    return value


@pytest.fixture
def studio(tmp_path):
    app = create_app(settings(tmp_path))
    upgrade(app.state.engine)
    verifier = app.state.staff_identity_verifier
    tokens = {"verified-owner-token-1234": claims(), "unenrolled-owner-token-123": claims(
        firebase={"tenant": "studio-tenant", "sign_in_provider": "google.com",
            "identities": {"google.com": ["google-owner"]}})}
    verifier.verify = lambda token: verifier.validate_claims(tokens[token])
    with TestClient(app) as client:
        yield app, client, tokens
    app.state.engine.dispose()


def test_setup_is_private_and_contains_no_staff_secret(studio, tmp_path):
    _app, client, _tokens = studio
    config = client.get("/v1/admin/auth/config")
    assert config.status_code == 200 and config.json()["tenantId"] == "studio-tenant"
    assert "google-owner" not in config.text
    assert "studio_staff_subjects" not in config.text
    page = client.get("/admin")
    assert page.status_code == 200
    assert "https://www.gstatic.com/firebasejs/12.4.0/" in page.headers["content-security-policy"]
    assert "https://apis.google.com" in page.headers["content-security-policy"]
    assert "https://staff-project.firebaseapp.com" in page.headers["content-security-policy"]
    assert page.headers["cache-control"] == "no-store"
    assert client.get("/admin/assets/signin.js").status_code == 200
    public = create_app(replace(settings(tmp_path), workload_role="api", studio_identity_project="",
        studio_identity_tenant="", studio_identity_api_key="", studio_identity_auth_domain=""))
    with TestClient(public) as game:
        for path in ("/admin", "/v1/admin/auth/config", "/v1/admin/auth/eligibility"):
            assert game.get(path).status_code == 404
    public.state.engine.dispose()


def test_enrollment_is_not_an_admin_session_and_audit_identity_stays_stable(studio):
    app, client, tokens = studio
    from bmt_backend.studio_access import staff_identity
    from bmt_backend.studio_platform_models import StudioStaff
    for token in tokens:
        eligible = client.post("/v1/admin/auth/eligibility", json={"id_token": token})
        assert eligible.status_code == 200
        assert eligible.json()["mfa_verified"] == (token == "verified-owner-token-1234")
    with app.state.session_factory() as db:
        assert db.get(StudioStaff, staff_identity("google-owner")) is None
    assert client.get("/v1/admin/staff", headers={"Authorization": "Bearer unenrolled-owner-token-123"}).status_code == 403
    accepted = client.get("/v1/admin/staff", headers={"Authorization": "Bearer verified-owner-token-1234"})
    assert accepted.status_code == 200
    assert accepted.json()["actor"] == staff_identity("google-owner")
    with app.state.session_factory() as db:
        db.get(StudioStaff, staff_identity("google-owner")).enabled = False
        db.commit()
    assert client.get("/v1/admin/staff", headers={"Authorization": "Bearer verified-owner-token-1234"}).status_code == 403
    assert client.post("/v1/admin/auth/eligibility", json={"id_token": "verified-owner-token-1234"}).status_code == 403


def test_other_google_identity_cannot_enroll_or_read(studio):
    _app, client, tokens = studio
    tokens["unlisted-owner-token-123"] = claims(firebase={**claims()["firebase"],
        "identities": {"google.com": ["other-google-user"]}})
    assert client.post("/v1/admin/auth/eligibility", json={"id_token": "unlisted-owner-token-123"}).status_code == 403
    assert client.get("/v1/admin/staff", headers={"Authorization": "Bearer unlisted-owner-token-123"}).status_code == 403


@pytest.mark.parametrize("updates", [
    {"iss": "https://accounts.google.com"}, {"aud": "game-client"}, {"email_verified": False},
    {"sub": ""}, {"auth_time": True}, {"auth_time": 0}, {"auth_time": int(time.time()) + 3600},
    {"firebase": []}, {"firebase": {**claims()["firebase"], "tenant": "other-tenant"}},
    {"firebase": {**claims()["firebase"], "sign_in_provider": "custom"}},
    {"firebase": {**claims()["firebase"], "identities": {"google.com": ["a", "b"]}}},
])
def test_rejects_wrong_issuer_audience_tenant_provider_and_stale_sign_in(tmp_path, updates):
    with pytest.raises(HTTPException) as denied:
        StudioIdentityVerifier(settings(tmp_path)).validate_claims(claims(**updates))
    assert denied.value.status_code == 401


@pytest.mark.parametrize("factor,identifier", [(None, "factor"), ("sms", "factor"), ("totp", ""), ("totp", None)])
def test_only_real_totp_claim_with_identifier_establishes_mfa(tmp_path, factor, identifier):
    value = claims()
    value["firebase"].update(sign_in_second_factor=factor, second_factor_identifier=identifier)
    assert StudioIdentityVerifier(settings(tmp_path)).validate_claims(value)["amr"] == []


def test_verifies_signature_using_fixed_google_certs_and_project_audience(tmp_path, monkeypatch):
    seen = {}
    def verify(token, transport, **kwargs):
        seen.update(kwargs)
        assert token == "signed-provider-token-123"
        return claims()
    monkeypatch.setattr("bmt_backend.studio_identity.id_token.verify_token", verify)
    assert StudioIdentityVerifier(settings(tmp_path)).verify("signed-provider-token-123")["amr"] == ["mfa"]
    assert seen == {"audience": "staff-project", "certs_url": CERTS}


def test_settings_refuse_partial_identity_or_public_service_setup(tmp_path):
    configured = settings(tmp_path)
    for update in ({"studio_identity_tenant": ""}, {"studio_identity_auth_domain": "attacker.example"},
                   {"studio_staff_audiences": ("game-client",)}, {"workload_role": "api"}):
        with pytest.raises(ValueError):
            replace(configured, **update)


def test_real_jwt_signature_and_expiry_validation(tmp_path):
    from datetime import datetime, timedelta, timezone
    from types import SimpleNamespace

    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.x509.oid import NameOID
    from google.auth import crypt, jwt

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption())
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Isolated test signer")])
    at = datetime.now(timezone.utc)
    certificate = (x509.CertificateBuilder().subject_name(name).issuer_name(name)
        .public_key(key.public_key()).serial_number(x509.random_serial_number())
        .not_valid_before(at - timedelta(minutes=1)).not_valid_after(at + timedelta(hours=1))
        .sign(key, hashes.SHA256()))
    verifier = StudioIdentityVerifier(settings(tmp_path))
    def certs(url, **kwargs):
        assert url == CERTS and kwargs["timeout"] == 5
        return SimpleNamespace(status=200, data=json.dumps({"test-key": certificate.public_bytes(
            serialization.Encoding.PEM).decode()}).encode())
    verifier.local.transport = certs
    signer = crypt.RSASigner.from_string(pem, key_id="test-key")
    payload = {**claims(), "iat": int(time.time()), "exp": int(time.time()) + 300}
    signed = jwt.encode(signer, payload).decode()
    assert verifier.verify(signed)["amr"] == ["mfa"]
    parts = signed.split(".")
    signature = parts[2]
    tampered = ".".join([parts[0], parts[1], ("A" if signature[0] != "A" else "B") + signature[1:]])
    for invalid in (tampered, jwt.encode(signer, {**payload, "iat": 1, "exp": 2}).decode(),
                    jwt.encode(signer, {**payload, "aud": "game-client"}).decode()):
        with pytest.raises(HTTPException) as denied:
            verifier.verify(invalid)
        assert denied.value.status_code == 401
