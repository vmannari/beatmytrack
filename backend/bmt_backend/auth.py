import secrets
import unicodedata

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .db import get_session
from .identity_models import Identity, LoginChallenge, Player, SessionFamily, SessionToken, now
from .middleware import ParsedJSONRoute
from .security import current_player, development_session_disabled, digest
from .usernames import DEVELOPER_NAME, DEVELOPER_NAME_KEY, username_key

router = APIRouter(route_class=ParsedJSONRoute, tags=["identity"])


class StrictBody(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class ProfileBody(StrictBody):
    display_name: str = Field(min_length=1, max_length=40)

    @field_validator("display_name")
    @classmethod
    def clean_name(cls, name):
        name = name.strip()
        if not name or any(unicodedata.category(c).startswith("C") for c in name):
            raise ValueError("Use a visible name without control characters")
        return name


class GoogleLogin(ProfileBody):
    display_name: str = "Racer"
    id_token: str = Field(min_length=20, max_length=16384)
    challenge_id: str = Field(min_length=36, max_length=36)


class RefreshBody(StrictBody):
    refresh_token: str = Field(min_length=32, max_length=128)


class DevelopmentLogin(ProfileBody):
    display_name: str = "Test racer"
    subject: str = Field(min_length=1, max_length=100, pattern=r"^[a-zA-Z0-9_.-]+$")


def require_available_name(
    session: Session, name: str, player_id: str | None = None, developer: bool = False
):
    key = username_key(name)
    if not developer and key == DEVELOPER_NAME_KEY:
        raise HTTPException(409, "USERNAME_TAKEN")
    owner = session.scalar(select(Player.id).where(Player.username_key == key))
    if owner is not None and owner != player_id:
        raise HTTPException(409, "USERNAME_TAKEN")


def public_player(player: Player) -> dict:
    return {
        "id": player.id,
        "display_name": player.display_name,
        "created_at": player.created_at,
        "needs_username": player.needs_username,
    }


@router.post("/auth/developer", include_in_schema=False)
def developer_login(
    request: Request,
    x_dev_auth_key: str | None = Header(default=None),
    session: Session = Depends(get_session),
):
    return development_login(
        DevelopmentLogin(subject="developer", display_name=DEVELOPER_NAME), request, x_dev_auth_key, session
    )


@router.post("/auth/development", include_in_schema=False)
def development_login(
    body: DevelopmentLogin,
    request: Request,
    x_dev_auth_key: str | None = Header(default=None),
    session: Session = Depends(get_session),
):
    settings = request.app.state.settings
    if not settings.dev_auth_enabled or settings.environment != "development":
        raise HTTPException(404, "NOT_FOUND")
    if x_dev_auth_key is None or not secrets.compare_digest(
        x_dev_auth_key.encode("utf-8"), settings.dev_auth_key.encode("utf-8")
    ):
        raise HTTPException(401, "INVALID_DEVELOPMENT_KEY")
    identity = session.scalar(
        select(Identity).where(Identity.provider == "development", Identity.subject == body.subject)
    )
    if identity:
        player = session.get(Player, identity.player_id)
    else:
        name = DEVELOPER_NAME if body.subject == "developer" else body.display_name
        if body.subject != "developer" and username_key(name) == DEVELOPER_NAME_KEY:
            raise HTTPException(409, "USERNAME_TAKEN")
        try:
            with session.begin_nested():
                player = Player(display_name=name)
                session.add(player)
                session.flush()
                session.add(Identity(player_id=player.id, provider="development", subject=body.subject))
                session.flush()
        except IntegrityError:
            identity = session.scalar(
                select(Identity).where(Identity.provider == "development", Identity.subject == body.subject)
            )
            if identity is None:
                raise HTTPException(409, "USERNAME_TAKEN") from None
            player = session.get(Player, identity.player_id)
    if player.disabled:
        raise HTTPException(403, "ACCOUNT_DISABLED")
    if body.subject == "developer":
        player.display_name = DEVELOPER_NAME
    family = SessionFamily(player_id=player.id, expires_at=now() + settings.refresh_ttl_seconds)
    session.add(family)
    session.flush()
    result = issue_tokens(session, family, player, settings)
    session.commit()
    return result


def issue_tokens(session: Session, family: SessionFamily, player: Player, settings) -> dict:
    access, refresh = secrets.token_urlsafe(32), secrets.token_urlsafe(48)
    expires = min(now() + settings.access_ttl_seconds, family.expires_at)
    session.add(
        SessionToken(
            family_id=family.id,
            access_hash=digest(access),
            refresh_hash=digest(refresh),
            access_expires_at=expires,
        )
    )
    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "Bearer",
        "expires_in": max(0, expires - now()),
        "refresh_expires_at": family.expires_at,
        "player": public_player(player),
    }


@router.post("/auth/google/challenge", status_code=201)
def google_challenge(request: Request, session: Session = Depends(get_session)):
    if not request.app.state.settings.google_client_ids:
        raise HTTPException(503, "GOOGLE_SIGN_IN_NOT_CONFIGURED")
    nonce = secrets.token_urlsafe(32)
    challenge = LoginChallenge(nonce_hash=digest(nonce), expires_at=now() + 300)
    session.add(challenge)
    session.commit()
    return {"challenge_id": challenge.id, "nonce": nonce, "expires_at": challenge.expires_at}


@router.post("/auth/google")
def google_login(body: GoogleLogin, request: Request, session: Session = Depends(get_session)):
    # Cryptographic verification precedes identity lookup; email is neither stored nor used for linking.
    claims = request.app.state.identity_verifier.verify(body.id_token)
    nonce = claims.get("nonce")
    if not isinstance(nonce, str):
        raise HTTPException(401, "INVALID_LOGIN_CHALLENGE")
    consumed = session.execute(
        update(LoginChallenge)
        .where(
            LoginChallenge.id == body.challenge_id,
            LoginChallenge.nonce_hash == digest(nonce),
            LoginChallenge.expires_at > now(),
            LoginChallenge.used.is_(False),
        )
        .values(used=True)
    )
    if consumed.rowcount != 1:
        raise HTTPException(401, "INVALID_LOGIN_CHALLENGE")
    return complete_google_login(claims["sub"], body.display_name, request, session)


def complete_google_login(subject: str, display_name: str | None, request: Request, session: Session):
    identity = session.scalar(
        select(Identity).where(Identity.provider == "google", Identity.subject == subject)
    )
    if identity:
        player = session.get(Player, identity.player_id)
    else:
        if display_name is not None and username_key(display_name) == DEVELOPER_NAME_KEY:
            raise HTTPException(409, "USERNAME_TAKEN")
        # Savepoint handles two valid Google sign-ins creating the same identity concurrently.
        try:
            with session.begin_nested():
                player = Player(display_name=display_name or "Racer", needs_username=display_name is None)
                session.add(player)
                session.flush()
                session.add(Identity(player_id=player.id, provider="google", subject=subject))
                session.flush()
        except IntegrityError:
            identity = session.scalar(
                select(Identity).where(Identity.provider == "google", Identity.subject == subject)
            )
            if identity is None:
                raise HTTPException(409, "USERNAME_TAKEN") from None
            player = session.get(Player, identity.player_id)
    if player.disabled:
        session.commit()
        raise HTTPException(403, "ACCOUNT_DISABLED")
    family = SessionFamily(
        player_id=player.id, expires_at=now() + request.app.state.settings.refresh_ttl_seconds
    )
    session.add(family)
    session.flush()
    result = issue_tokens(session, family, player, request.app.state.settings)
    session.commit()
    return result


@router.post("/auth/refresh")
def refresh_session(body: RefreshBody, request: Request, session: Session = Depends(get_session)):
    token = session.scalar(
        select(SessionToken).where(SessionToken.refresh_hash == digest(body.refresh_token)).with_for_update()
    )
    if token is None:
        raise HTTPException(401, "INVALID_SESSION")
    family = session.scalar(
        select(SessionFamily).where(SessionFamily.id == token.family_id).with_for_update()
    )
    player = session.get(Player, family.player_id)
    if token.consumed:
        family.revoked = True
        session.commit()  # Replayed refresh revokes the replacement too.
        raise HTTPException(401, "REFRESH_REUSE_DETECTED")
    if (
        family.revoked
        or family.expires_at <= now()
        or player.disabled
        or development_session_disabled(request, session, player)
    ):
        raise HTTPException(401, "INVALID_SESSION")
    token.consumed = True
    result = issue_tokens(session, family, player, request.app.state.settings)
    session.commit()
    return result


@router.post("/auth/logout", status_code=204)
def logout(
    request: Request, player: Player = Depends(current_player), session: Session = Depends(get_session)
):
    session.execute(
        update(SessionFamily).where(SessionFamily.id == request.state.session_family_id).values(revoked=True)
    )
    session.commit()


@router.post("/auth/logout-all", status_code=204)
def logout_all(player: Player = Depends(current_player), session: Session = Depends(get_session)):
    session.execute(update(SessionFamily).where(SessionFamily.player_id == player.id).values(revoked=True))
    session.commit()


@router.get("/me")
def me(player: Player = Depends(current_player)):
    return public_player(player)


@router.patch("/me")
def profile(
    body: ProfileBody, player: Player = Depends(current_player), session: Session = Depends(get_session)
):
    developer = session.scalar(
        select(Identity).where(
            Identity.player_id == player.id,
            Identity.provider == "development",
            Identity.subject == "developer",
        )
    )
    if developer and body.display_name != DEVELOPER_NAME:
        raise HTTPException(403, "DEVELOPER_NAME_FIXED")
    require_available_name(session, body.display_name, player.id, developer=developer is not None)
    player.display_name = body.display_name
    player.needs_username = False
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(409, "USERNAME_TAKEN") from None
    return public_player(player)
