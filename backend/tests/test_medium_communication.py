"""Revocation, provider IO ownership and real HTTP pooling regressions; no cloud calls."""
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event, select, update
from test_auth_postgres import google_request
from test_auth_postgres import postgres_auth as postgres_auth_fixture

from bmt_backend.app import create_app
from bmt_backend.http_transport import PooledTransport
from bmt_backend.identity_models import BrowserLogin, SessionFamily, SessionToken, now
from bmt_backend.security import digest

postgres_auth = postgres_auth_fixture


@pytest.mark.parametrize("credential", ["refresh", "expired_access", "consumed_refresh"])
def test_logout_revokes_only_owned_family_without_live_access(auth_app, auth_client, sign_in, credential):
    first, other = sign_in("alice"), sign_in("bob")
    with auth_app.state.session_factory() as session:
        session.execute(update(SessionToken).where(SessionToken.access_hash == digest(first["access_token"]))
                        .values(access_expires_at=now()-1))
        session.commit()
    replacement = None
    if credential == "consumed_refresh":
        replacement = auth_client.post("/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}).json()
    kwargs = {"json": {"refresh_token": first["refresh_token"]}} if credential != "expired_access" else {
        "headers": {"Authorization": "Bearer " + first["access_token"]}}
    assert auth_client.post("/v1/auth/logout", **kwargs).status_code == 204
    assert auth_client.post("/v1/auth/logout", **kwargs).status_code == 204
    refresh = replacement["refresh_token"] if replacement else first["refresh_token"]
    assert auth_client.post("/v1/auth/refresh", json={"refresh_token": refresh}).status_code == 401
    assert auth_client.get("/v1/me", headers={"Authorization": "Bearer " + other["access_token"]}).status_code == 200


def test_logout_rejects_guess_and_retains_every_family(auth_app, auth_client, sign_in):
    sign_in()
    assert auth_client.post("/v1/auth/logout", json={"refresh_token": "x" * 43}).status_code == 401
    assert auth_client.post("/v1/auth/logout").status_code == 401
    with auth_app.state.session_factory() as session:
        assert not any(session.scalars(select(SessionFamily.revoked)))


@pytest.mark.parametrize("changed", [None, "expires", "consumed", "completed", "nonce", "provider_failure"])
def test_browser_complete_releases_pool_and_rechecks_challenge(auth_app, changed):
    settings = replace(auth_app.state.settings, google_web_client_id="test-client", public_base_url="https://game.example")
    app = create_app(settings, engine=auth_app.state.engine, identity_verifier=auth_app.state.identity_verifier)
    with TestClient(app) as client:
        started = client.post("/v1/auth/google/browser/start", json={}).json()
        token = started["browser_url"].split("#")[1]
        prepared = client.post("/v1/auth/google/browser/prepare", json={"token": token}).json()
        checked_out = set()
        def checkout(_dbapi, record, _proxy):
            checked_out.add(id(record))
        def checkin(_dbapi, record):
            checked_out.discard(id(record))
        event.listen(app.state.engine, "checkout", checkout)
        event.listen(app.state.engine, "checkin", checkin)
        def verify(_token):
            assert checked_out == set(), "Provider IO holds a checked-out DB connection"
            if changed == "provider_failure":
                from fastapi import HTTPException
                raise HTTPException(503, "IDENTITY_PROVIDER_UNAVAILABLE")
            if changed:
                fields = {"expires": {"expires_at": now()-1}, "consumed": {"consumed": True},
                          "completed": {"subject": "other-subject"}, "nonce": {"nonce": "replacement-nonce"}}[changed]
                with app.state.session_factory() as session:
                    session.execute(update(BrowserLogin).values(**fields))
                    session.commit()
            return {"sub": "alice", "aud": "test-client", "nonce": prepared["nonce"]}
        original = app.state.identity_verifier.verify
        app.state.identity_verifier.verify = verify
        try:
            response = client.post("/v1/auth/google/browser/complete", json={"token": token, "id_token": "t" * 32})
            assert response.status_code == (200 if changed is None else 503 if changed == "provider_failure" else 401)
            assert checked_out == set()
        finally:
            app.state.identity_verifier.verify = original
            event.remove(app.state.engine, "checkout", checkout)
            event.remove(app.state.engine, "checkin", checkin)


def test_real_transport_reuses_tcp_isolates_threads_and_closes():
    ports = []
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        def do_GET(self):
            ports.append(self.client_address[1])
            self.send_response(200)
            self.send_header("Content-Length", "2")
            self.end_headers()
            self.wfile.write(b"{}")
        def log_message(self, *_args):
            pass
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever)
    thread.start()
    transport = PooledTransport()
    url = f"http://127.0.0.1:{server.server_port}/object"
    def pair():
        for _ in range(2):
            with transport("GET", url, timeout=(1, 2), stream=True, allow_redirects=False) as response:
                assert response.content == b"{}"
    try:
        pair()
        assert ports[0] == ports[1], "Sequential calls created another TCP connection"
        with ThreadPoolExecutor(max_workers=1) as worker:
            worker.submit(pair).result(timeout=5)
        assert ports[2] == ports[3] and ports[0] != ports[2]
        assert len(transport.sessions) == 2
        for session in transport.sessions.values():
            assert session.get_adapter(url).max_retries.total == 0
        transport.close()
        transport.close()
        assert transport.sessions == {}
        with pytest.raises(OSError, match="closed"):
            transport("GET", url)
    finally:
        transport.close()
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def test_patched_crypto_verifies_real_google_rsa_tokens_offline():
    import json
    import time
    from datetime import datetime, timedelta, timezone
    from types import SimpleNamespace

    import cryptography
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from fastapi import HTTPException
    from google.auth import crypt, jwt
    from packaging.version import Version

    from bmt_backend.security import GoogleIdentityVerifier

    assert Version(cryptography.__version__) >= Version("50.0.2")
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    subject = x509.Name([x509.NameAttribute(x509.NameOID.COMMON_NAME, "offline-fixture")])
    at = datetime.now(timezone.utc)
    certificate = (x509.CertificateBuilder().subject_name(subject).issuer_name(subject)
                   .public_key(key.public_key()).serial_number(x509.random_serial_number())
                   .not_valid_before(at-timedelta(minutes=1)).not_valid_after(at+timedelta(hours=1))
                   .sign(key, hashes.SHA256()).public_bytes(serialization.Encoding.PEM).decode())
    signer = crypt.RSASigner(key, key_id="offline-key")
    claims = {"sub": "offline-player", "aud": "fixture-client", "iss": "https://accounts.google.com",
              "iat": int(time.time())-10, "exp": int(time.time())+60}
    verifier = GoogleIdentityVerifier(("fixture-client",))
    def certificates(url, **kwargs):
        assert url == "https://www.googleapis.com/oauth2/v1/certs" and kwargs["timeout"] == 5
        return SimpleNamespace(status=200, data=json.dumps({"offline-key": certificate}).encode())
    verifier.local.transport = certificates
    signed = jwt.encode(signer, claims).decode()
    assert verifier.verify(signed)["sub"] == "offline-player"
    for changes in ({"aud": "wrong-client"}, {"exp": int(time.time())-60}, {"iss": "https://untrusted.example"}):
        with pytest.raises(HTTPException) as error:
            verifier.verify(jwt.encode(signer, {**claims, **changes}).decode())
        assert error.value.status_code == 401
    sections = signed.split(".")
    sections[-1] = ("A" if sections[-1][0] != "A" else "B") + sections[-1][1:]
    with pytest.raises(HTTPException):
        verifier.verify(".".join(sections))


@pytest.mark.postgres
def test_postgres_logout_refresh_race_never_leaves_a_live_family(postgres_auth):
    app, client = postgres_auth
    original = client.post("/v1/auth/google", json=google_request(app, client, "logout-race")).json()
    barrier = threading.Barrier(2)
    def refresh():
        barrier.wait(timeout=5)
        return client.post("/v1/auth/refresh", json={"refresh_token": original["refresh_token"]})
    def logout():
        barrier.wait(timeout=5)
        return client.post("/v1/auth/logout", json={"refresh_token": original["refresh_token"]})
    with ThreadPoolExecutor(max_workers=2) as executor:
        pending = executor.submit(refresh)
        revoked = executor.submit(logout)
        refreshed = pending.result(timeout=10)
        assert revoked.result(timeout=10).status_code == 204
    assert refreshed.status_code in (200, 401)
    with app.state.session_factory() as session:
        assert session.scalar(select(SessionFamily.revoked)) is True
    if refreshed.status_code == 200:
        assert client.get("/v1/me", headers={"Authorization": "Bearer " + refreshed.json()["access_token"]}).status_code == 401


@pytest.mark.postgres
def test_postgres_provider_io_returns_the_connection(postgres_auth):
    # Run the same checkout assertion and concurrent consumed-challenge fence on
    # an actual PostgreSQL pool, not SQLite's transaction approximation.
    test_browser_complete_releases_pool_and_rechecks_challenge(postgres_auth[0], "consumed")
