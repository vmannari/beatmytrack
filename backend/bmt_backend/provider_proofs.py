"""Provider proof adapters. No client callbacks or catalog prices confer paid authority.

Integration deliberately stays unavailable until package, products, SSV placement,
acknowledgement/reconciliation jobs and reversal policy have been configured.
"""
import base64
import hashlib
import hmac
import json
import re
import threading
import time
from datetime import datetime, timezone
from urllib.parse import parse_qsl, quote, unquote_to_bytes

import google.auth
import requests
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from google.auth.transport.requests import AuthorizedSession


class InvalidProof(ValueError):
    """Messages never contain receipt tokens, callback data or provider responses."""


class ProviderUnavailable(RuntimeError):
    pass


def account_binding(player_id):
    return hashlib.sha256(("bmt-play-player-v1/" + player_id).encode()).hexdigest()


def bounded_response(response, limit=16384):
    if response.status_code != 200:
        response.close()
        raise ProviderUnavailable("PROVIDER_RESPONSE_UNAVAILABLE")
    try:
        content = bytearray()
        for chunk in response.iter_content(4096):
            content.extend(chunk)
            if len(content) > limit:
                raise ProviderUnavailable("PROVIDER_RESPONSE_TOO_LARGE")
        return json.loads(content)
    except (ValueError, UnicodeError):
        raise ProviderUnavailable("INVALID_PROVIDER_RESPONSE") from None
    finally:
        response.close()


class PlayVerifier:
    def __init__(self, package, *, http=None):
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", package):
            raise ValueError("EXPLICIT_PLAY_PACKAGE_REQUIRED")
        self.package, self.http, self.lock = package, http, threading.Lock()

    def verify(self, token, product_id, player_id, *, at=None):
        if not isinstance(token, str) or not re.fullmatch(r"[A-Za-z0-9._~:+/=-]{1,4096}", token):
            raise InvalidProof("INVALID_PURCHASE_TOKEN")
        url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + quote(self.package, safe="")
        url += "/purchases/productsv2/tokens/" + quote(token, safe="")
        # No database lock is held while the provider is contacted. Serialize ADC
        # refresh and cap concurrent calls per instance; caller supplies backpressure.
        with self.lock:
            try:
                if self.http is None:
                    credentials, _project = google.auth.default(scopes=["https://www.googleapis.com/auth/androidpublisher"])
                    self.http = AuthorizedSession(credentials)
                response = self.http.get(url, timeout=(3, 5), stream=True, allow_redirects=False)
                proof = bounded_response(response)
            except ProviderUnavailable:
                raise
            except (google.auth.exceptions.GoogleAuthError, requests.exceptions.RequestException, OSError):
                raise ProviderUnavailable("PLAY_VERIFICATION_UNAVAILABLE") from None
        return validate_play(proof, product_id, player_id, at=int(time.time()) if at is None else at)


def validate_play(proof, product_id, player_id, *, at):
    if not isinstance(proof, dict):
        raise InvalidProof("INVALID_PLAY_PROOF")
    expected = account_binding(player_id)
    actual = proof.get("obfuscatedExternalAccountId")
    if not isinstance(actual, str) or not re.fullmatch(r"[a-f0-9]{64}", actual) or not hmac.compare_digest(expected, actual):
        raise InvalidProof("PURCHASE_ACCOUNT_MISMATCH")
    items = proof.get("productLineItem")
    if not isinstance(items, list) or len(items) != 1 or not isinstance(items[0], dict) or items[0].get("productId") != product_id:
        raise InvalidProof("PURCHASE_PRODUCT_MISMATCH")
    offer = items[0].get("productOfferDetails", {})
    if not isinstance(offer, dict) or type(offer.get("quantity")) is not int or offer["quantity"] != 1:
        raise InvalidProof("UNSUPPORTED_PURCHASE_QUANTITY")
    if "rentOfferDetails" in offer or "preorderOfferDetails" in offer:
        raise InvalidProof("UNSUPPORTED_PRODUCT_OFFER")
    state = proof.get("purchaseStateContext", {})
    state = state.get("purchaseState") if isinstance(state, dict) else None
    if state not in ("PURCHASED", "PENDING", "CANCELLED"):
        raise InvalidProof("INVALID_PURCHASE_STATE")
    completed = None
    if state == "PURCHASED":
        try:
            if not isinstance(proof.get("purchaseCompletionTime"), str):
                raise TypeError()
            date = datetime.fromisoformat(proof["purchaseCompletionTime"].replace("Z", "+00:00"))
            if date.tzinfo is None:
                raise ValueError()
            completed = int(date.astimezone(timezone.utc).timestamp())
            if not 0 <= completed <= at + 300:
                raise ValueError()
        except (KeyError, TypeError, ValueError, OverflowError):
            raise InvalidProof("INVALID_PURCHASE_COMPLETION_TIME") from None
    refundable = offer.get("refundableQuantity")
    if type(refundable) is not int or refundable not in (0, 1):
        raise InvalidProof("INVALID_REFUNDABLE_QUANTITY")
    return {"product_id": product_id, "state": state, "completed_at": completed,
        "test_purchase": "testPurchaseContext" in proof,
        "refundable_quantity": refundable, "acknowledgement": proof.get("acknowledgementState"),
        "consumption": offer.get("consumptionState")}


class AdMobKeys:
    """Trusted Google keys only; bounded response/cache and paced unknown-key refresh."""
    URL = "https://www.gstatic.com/admob/reward/verifier-keys.json"

    def __init__(self, *, http=None, clock=time.monotonic):
        self.http, self.clock = http or requests.Session(), clock
        self.keys, self.expires, self.refresh_after = {}, 0, 0
        self.lock = threading.Lock()

    def key(self, key_id):
        with self.lock:
            at = self.clock()
            if at < self.expires and key_id in self.keys:
                return self.keys[key_id]
            if at >= self.refresh_after:
                self.refresh_after = at + 60
                try:
                    value = bounded_response(self.http.get(self.URL, timeout=(3, 5), stream=True, allow_redirects=False))
                    rows = value["keys"]
                    if not isinstance(rows, list) or not 1 <= len(rows) <= 10:
                        raise ValueError()
                    keys = {}
                    for row in rows:
                        key = serialization.load_der_public_key(base64.b64decode(row["base64"], validate=True))
                        if not isinstance(key, ec.EllipticCurvePublicKey) or not isinstance(key.curve, (ec.SECP256R1, ec.SECP224R1)):
                            raise TypeError()
                        keys[str(row["keyId"])] = key
                    self.keys, self.expires = keys, at + 3600
                except (ProviderUnavailable, requests.exceptions.RequestException, KeyError, TypeError, ValueError):
                    raise ProviderUnavailable("ADMOB_KEYS_UNAVAILABLE") from None
            if at >= self.expires:
                raise ProviderUnavailable("ADMOB_KEYS_EXPIRED")
            if key_id not in self.keys:
                raise InvalidProof("UNKNOWN_ADMOB_KEY")
            return self.keys[key_id]


def verify_admob(raw_query, keys):
    """Match Google's URI.getQuery() canonicalization before parsing business fields."""
    if not isinstance(raw_query, bytes) or not 1 <= len(raw_query) <= 4096:
        raise InvalidProof("INVALID_ADMOB_QUERY")
    try:
        content, signature = raw_query.rsplit(b"&signature=", 1)
        signature, key_id = signature.split(b"&key_id=")
        signature = unquote_to_bytes(signature)
        if not re.fullmatch(rb"[0-9]{1,20}", key_id) or not re.fullmatch(rb"[A-Za-z0-9_-]{1,128}={0,2}", signature):
            raise ValueError()
        signed = base64.b64decode(signature + b"=" * (-len(signature) % 4), altchars=b"-_", validate=True)
        # Google's reference verifies URI.getQuery(): percent decode once, keep
        # literal '+' and original parameter order. Do not use form decoding or
        # serialize a parsed dictionary to reconstruct the signed message.
        verified_content = unquote_to_bytes(content)
        verified_content.decode("utf-8", errors="strict")
        keys.key(key_id.decode("ascii")).verify(signed, verified_content, ec.ECDSA(hashes.SHA256()))
        pairs = parse_qsl(content.decode("ascii"), keep_blank_values=True, strict_parsing=True,
            encoding="utf-8", errors="strict", max_num_fields=16)
        value = dict(pairs)
        allowed = {"ad_network", "ad_unit", "custom_data", "reward_amount", "reward_item", "timestamp", "transaction_id", "user_id"}
        if len(pairs) != len(value) or not set(value) <= allowed or not (allowed - {"user_id"}) <= set(value):
            raise ValueError()
        if value["reward_amount"] != "1" or value["reward_item"] != "resume":
            raise InvalidProof("UNSUPPORTED_AD_REWARD")
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", value["transaction_id"]) or not re.fullmatch(r"[0-9]{1,20}", value["timestamp"]):
            raise ValueError()
        # Placement and opaque server-issued intent must be checked by fulfillment.
        # Signature verification alone never grants a resource or attributes revenue.
        return value
    except (ValueError, UnicodeError, InvalidSignature) as error:
        if isinstance(error, InvalidProof):
            raise
        raise InvalidProof("INVALID_ADMOB_PROOF") from None
