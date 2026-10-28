"""Managed Google sign-in and TOTP; only the private Studio listener serves setup."""

import threading
import time

import requests
from cachecontrol import CacheControl
from fastapi import APIRouter, HTTPException, Request
from google.auth.exceptions import GoogleAuthError, TransportError
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import id_token
from pydantic import BaseModel, ConfigDict, Field

from .middleware import ParsedJSONRoute
from .studio_settings import mapping

CERTS = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
router = APIRouter(route_class=ParsedJSONRoute, tags=["staff sign-in"])


class StudioIdentityVerifier:
    def __init__(self, settings):
        self.settings = settings
        self.local = threading.local()

    def verify(self, token):
        if not isinstance(token, str) or not 20 <= len(token) <= 16384:
            raise HTTPException(401, "INVALID_STAFF_TOKEN")
        if not hasattr(self.local, "transport"):
            self.local.transport = GoogleRequest(session=CacheControl(requests.Session()))

        def bounded_request(*args, **kwargs):
            kwargs["timeout"] = 5
            return self.local.transport(*args, **kwargs)

        try:
            claims = id_token.verify_token(token, bounded_request,
                audience=self.settings.studio_identity_project, certs_url=CERTS)
        except TransportError as exc:
            raise HTTPException(503, "IDENTITY_PROVIDER_UNAVAILABLE") from exc
        except (ValueError, TypeError, GoogleAuthError) as exc:
            raise HTTPException(401, "INVALID_STAFF_TOKEN") from exc
        return self.validate_claims(claims)

    def validate_claims(self, claims):
        project = self.settings.studio_identity_project
        firebase = claims.get("firebase")
        if not isinstance(firebase, dict):
            raise HTTPException(401, "INVALID_STAFF_TOKEN")
        identities = firebase.get("identities")
        subjects = identities.get("google.com") if isinstance(identities, dict) else None
        at = int(time.time())
        auth_time = claims.get("auth_time")
        if (claims.get("iss") != "https://securetoken.google.com/" + project
                or claims.get("aud") != project
                or firebase.get("tenant") != self.settings.studio_identity_tenant
                or firebase.get("sign_in_provider") != "google.com"
                or claims.get("email_verified") is not True
                or not isinstance(claims.get("sub"), str) or not 1 <= len(claims["sub"]) <= 128
                or not isinstance(subjects, list) or len(subjects) != 1
                or not isinstance(subjects[0], str) or not 1 <= len(subjects[0]) <= 255
                or type(auth_time) is not int or not at - 3600 < auth_time <= at + 30):
            raise HTTPException(401, "INVALID_STAFF_TOKEN")
        # Keep the existing Google-subject allowlist and audit identity stable.
        return {"sub": subjects[0], "amr": ["mfa"] if (
            firebase.get("sign_in_second_factor") == "totp"
            and isinstance(firebase.get("second_factor_identifier"), str)
            and firebase["second_factor_identifier"]
        ) else []}


@router.get("/v1/admin/auth/config")
def config(request: Request):
    from .studio_reporting import reporting_policy
    settings = request.app.state.settings
    configured = bool(settings.studio_identity_project)
    return {"configured": configured, "legacy_enabled": settings.studio_legacy_keys_enabled,
            "reporting": reporting_policy(settings),
            **({"apiKey": settings.studio_identity_api_key,
                "projectId": settings.studio_identity_project,
                "authDomain": settings.studio_identity_auth_domain,
                "tenantId": settings.studio_identity_tenant,
                "loginHint": settings.studio_identity_login_hint} if configured else {})}


class Eligibility(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id_token: str = Field(min_length=20, max_length=16384)


@router.post("/v1/admin/auth/eligibility")
def eligibility(body: Eligibility, request: Request):
    """Permit MFA enrollment for allowlisted Google identities, granting no Studio access."""
    settings = request.app.state.settings
    if not settings.studio_identity_project:
        raise HTTPException(503, "STAFF_BROWSER_SIGN_IN_NOT_CONFIGURED")
    claims = request.app.state.staff_identity_verifier.verify(body.id_token)
    entry = mapping(settings.studio_staff_subjects).get(claims["sub"])
    if not entry:
        raise HTTPException(403, "STAFF_NOT_AUTHORISED")
    # An operator-disabled staff member must not be offered an enrollment path.
    from .studio_access import staff_identity
    from .studio_platform_models import StudioStaff
    with request.app.state.session_factory() as db:
        row = db.get(StudioStaff, staff_identity(claims["sub"]))
        if row is not None and not row.enabled:
            raise HTTPException(403, "STAFF_ACCESS_DISABLED")
    return {"name": entry["name"], "mfa_verified": "mfa" in claims["amr"]}
