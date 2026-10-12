import hashlib
import threading

import requests
from cachecontrol import CacheControl
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google.auth.exceptions import GoogleAuthError, TransportError
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import id_token
from sqlalchemy import select
from sqlalchemy.orm import Session

from .db import get_session
from .identity_models import Identity, Player, SessionFamily, SessionToken, now


def digest(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


class GoogleIdentityVerifier:
    """Only Google's signed issuer/audience/expiry validation can establish identity."""

    def __init__(self, client_ids: tuple[str, ...]):
        self.client_ids = client_ids
        self.local = threading.local()

    def verify(self, token: str) -> dict:
        if not self.client_ids:
            raise HTTPException(503, "GOOGLE_SIGN_IN_NOT_CONFIGURED")
        if not hasattr(self.local, "transport"):
            self.local.transport = GoogleRequest(session=CacheControl(requests.Session()))

        def bounded_request(*args, **kwargs):
            kwargs["timeout"] = 5
            return self.local.transport(*args, **kwargs)

        try:
            claims = id_token.verify_oauth2_token(token, bounded_request, audience=list(self.client_ids))
        except TransportError as exc:
            raise HTTPException(503, "IDENTITY_PROVIDER_UNAVAILABLE") from exc
        except (ValueError, TypeError, GoogleAuthError) as exc:
            raise HTTPException(401, "INVALID_GOOGLE_TOKEN") from exc
        if not isinstance(claims.get("sub"), str) or not 1 <= len(claims["sub"]) <= 255:
            raise HTTPException(401, "INVALID_GOOGLE_TOKEN")
        # Hybrid/multiple-audience tokens must also name an authorized presenting client.
        if "azp" in claims and claims["azp"] not in self.client_ids:
            raise HTTPException(401, "INVALID_GOOGLE_TOKEN")
        return claims


bearer = HTTPBearer(auto_error=False)


def development_session_disabled(request: Request, session: Session, player: Player) -> bool:
    settings = request.app.state.settings
    if player.is_test_driver and not settings.test_drivers_enabled:
        return True
    if settings.environment == "development" and settings.dev_auth_enabled:
        return False
    return (
        session.scalar(
            select(Identity.id).where(Identity.player_id == player.id, Identity.provider == "development")
        )
        is not None
    )


def current_player(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    session: Session = Depends(get_session),
) -> Player:
    cached = getattr(request.state,"authenticated_player",None)
    if cached is not None:
        return cached
    if credentials is None or credentials.scheme.lower() != "bearer" or len(credentials.credentials) > 256:
        raise HTTPException(401, "AUTH_REQUIRED", headers={"WWW-Authenticate": "Bearer"})
    row = session.execute(
        select(Player, SessionFamily, SessionToken)
        .join(SessionFamily, SessionFamily.player_id == Player.id)
        .join(SessionToken, SessionToken.family_id == SessionFamily.id)
        .where(SessionToken.access_hash == digest(credentials.credentials))
    ).first()
    if row is None:
        raise HTTPException(401, "INVALID_SESSION")
    player, family, token = row
    if (
        player.disabled
        or family.revoked
        or family.expires_at <= now()
        or token.access_expires_at <= now()
        or token.consumed
        or development_session_disabled(request, session, player)
    ):
        raise HTTPException(401, "INVALID_SESSION")
    request.state.session_family_id = family.id
    # Release authentication's connection before reserving a rate lease.
    # Saturated replicas must never require a nested second connection.
    session.commit()
    if not getattr(request.state, "player_budget_checked", False):
        read = request.method in ("GET", "HEAD")
        limit = request.app.state.settings.rate_limit_per_minute if read else request.app.state.settings.write_limit_per_minute
        cost = 4 if request.url.path == "/v1/runs" else 2 if request.url.path == "/v1/tracks" else 1
        if not request.app.state.identity_budgets.allow(player.id, "player_read" if read else "player_write", limit, 1 if read else cost, session=session):
            raise HTTPException(429, "RATE_LIMITED")
        request.state.player_budget_checked = True
    request.state.authenticated_player = player
    return player
