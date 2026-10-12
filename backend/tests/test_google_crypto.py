"""Real RSA signatures with an isolated local Google certificate transport."""

import datetime
import json
import time

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
from fastapi import HTTPException
from google.auth import crypt, jwt

from bmt_backend.security import GoogleIdentityVerifier


@pytest.fixture(scope="module")
def keys():
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "isolated-test")])
    current = datetime.datetime.now(datetime.timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(current - datetime.timedelta(days=1))
        .not_valid_after(current + datetime.timedelta(days=1))
        .sign(key, hashes.SHA256())
    )
    signer = crypt.RSASigner.from_string(
        key.private_bytes(
            serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
        )
    )
    return signer, cert.public_bytes(serialization.Encoding.PEM).decode()


def token_and_verifier(keys, **claims):
    signer, certificate = keys
    verifier = GoogleIdentityVerifier(("our-client",))

    class Reply:
        status = 200
        data = json.dumps({"test-key": certificate}).encode()

    verifier.local.transport = lambda *a, **kw: Reply()
    payload = {
        "sub": "google-subject",
        "aud": "our-client",
        "iss": "https://accounts.google.com",
        "iat": int(time.time()) - 5,
        "exp": int(time.time()) + 300,
        "nonce": "challenge-nonce",
        **claims,
    }
    return jwt.encode(signer, payload, key_id="test-key").decode(), verifier


def test_signed_google_token(keys):
    token, verifier = token_and_verifier(keys)
    assert verifier.verify(token)["sub"] == "google-subject"


def test_android_presenter_requires_explicit_client_configuration(keys):
    token, verifier = token_and_verifier(keys, azp="our-android-client")
    with pytest.raises(HTTPException) as error:
        verifier.verify(token)
    assert error.value.status_code == 401
    verifier.client_ids = ("our-client", "our-android-client")
    assert verifier.verify(token)["aud"] == "our-client"
    wrong_token, _ = token_and_verifier(keys, azp="unrelated-android-client")
    with pytest.raises(HTTPException) as error:
        verifier.verify(wrong_token)
    assert error.value.status_code == 401


@pytest.mark.parametrize(
    "claims",
    [
        {"aud": "someone-else"},
        {"iss": "https://evil.invalid"},
        {"exp": 100},
        {"azp": "unknown-client"},
        {"sub": ""},
        {"iat": {}},
        {"exp": "tomorrow"},
    ],
)
def test_wrong_claims_rejected(keys, claims):
    token, verifier = token_and_verifier(keys, **claims)
    with pytest.raises(HTTPException) as error:
        verifier.verify(token)
    assert error.value.status_code == 401


def test_tampered_signature_rejected(keys):
    token, verifier = token_and_verifier(keys)
    parts = token.split(".")
    parts[2] = ("A" if parts[2][0] != "A" else "B") + parts[2][1:]
    with pytest.raises(HTTPException):
        verifier.verify(".".join(parts))


def test_google_config_missing_fails_closed():
    with pytest.raises(HTTPException) as error:
        GoogleIdentityVerifier(()).verify("untrusted")
    assert error.value.status_code == 503
