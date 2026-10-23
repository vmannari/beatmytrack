"""Public-content rules, durable consent, and private player blocking."""
from html import escape
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict
from sqlalchemy import delete, func, or_, select

from .community_models import CommunityAcceptance, PlayerBlock
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .security import bearer, current_player
from .tracks import DB, Auth

router = APIRouter(route_class=ParsedJSONRoute, tags=["community safety"])
TERMS_VERSION = "bmt-community-2026-10-16"
TERMS = """Public sharing rules
Only share tracks, names, challenge titles and car designs you have the right to use. Do not publish personal or confidential information about yourself or anyone else.
No sexual content or nudity; child sexual abuse or exploitation; threats, bullying or harassment; hate or discrimination; graphic violence; encouragement of self-harm; illegal activity; scams, spam or impersonation. Do not use track shapes, names, stickers or other game features to evade these rules. Do not misuse reports to harass others.
Public tracks and your public racing profile can be seen and downloaded by other players. You keep your rights and allow Beat my track to host, display and distribute what you deliberately share to operate the game. Previously downloaded copies may remain after removal. Account deletion retains published tracks and historical results under Removed account.
Use Report track or Report player to send a private report to the Beat my track moderation owner in Backend Studio. Reports are reviewed by a person; submitting a report does not automatically remove content. Moderators may hide tracks or restrict accounts, including for repeated abuse. You can check your reports and appeal a resolved report in Settings > Privacy > Community safety.
Block player hides that player's tracks and public identity on this account and prevents new challenge interactions between you. Blocking is private, can be undone in Community safety, and does not erase historical scores or existing race evidence.
These rules apply to all public sharing, including purchased publishing slots. Payment never exempts content from moderation. Accept these rules before uploading or publishing; a changed version requires fresh acceptance. Local editing and offline play do not require acceptance."""


def require_terms(session, player_id):
    if session.get(CommunityAcceptance, (player_id, TERMS_VERSION)) is None:
        raise HTTPException(403, "COMMUNITY_TERMS_REQUIRED")


def blocked_ids(session, player_id):
    return select(PlayerBlock.blocked_id).where(PlayerBlock.player_id == player_id)


def is_blocked(session, player_id, other_id, *, mutual=False):
    if not player_id or not other_id:
        return False
    query = (PlayerBlock.player_id == player_id) & (PlayerBlock.blocked_id == other_id)
    if mutual:
        query = or_(query, (PlayerBlock.player_id == other_id) & (PlayerBlock.blocked_id == player_id))
    return session.scalar(select(PlayerBlock.player_id).where(query).limit(1)) is not None


def check_creator(session, player_id, creator_id):
    if is_blocked(session, player_id, creator_id):
        raise HTTPException(403, "PLAYER_BLOCKED")


@router.get("/v1/community/terms")
def terms(request: Request, session: DB, credentials=Depends(bearer)):
    player = current_player(request, credentials, session) if credentials else None
    acceptance = session.get(CommunityAcceptance, (player.id, TERMS_VERSION)) if player else None
    return {"version": TERMS_VERSION, "text": TERMS, "accepted": acceptance is not None,
            "accepted_at": acceptance.accepted_at if acceptance else None, "moderation_role": "Backend Studio owner"}


class Accept(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    version: str
    accepted: Literal[True]


@router.post("/v1/community/terms")
def accept_terms(body: Accept, session: DB, player: Auth):
    if body.version != TERMS_VERSION:
        raise HTTPException(409, "COMMUNITY_TERMS_CHANGED")
    acceptance = session.get(CommunityAcceptance, (player.id, TERMS_VERSION))
    if acceptance is None:
        acceptance = CommunityAcceptance(player_id=player.id, version=TERMS_VERSION)
        session.add(acceptance)
    session.commit()
    return {"version": TERMS_VERSION, "accepted": True, "accepted_at": acceptance.accepted_at}


@router.get("/v1/community/blocks")
def blocks(session: DB, player: Auth):
    rows = session.execute(select(PlayerBlock.blocked_id, Player.display_name).join(
        Player, Player.id == PlayerBlock.blocked_id).where(PlayerBlock.player_id == player.id)
        .order_by(PlayerBlock.created_at.desc(), PlayerBlock.blocked_id).limit(1000)).all()
    return {"items": [{"player_id": row[0], "display_name": row[1]} for row in rows]}


@router.put("/v1/community/blocks/{target_id}")
def block(target_id: UUID, session: DB, player: Auth):
    target_id = str(target_id)
    if target_id == player.id:
        raise HTTPException(422, "CANNOT_BLOCK_SELF")
    if session.get(Player, target_id) is None:
        raise HTTPException(404, "PLAYER_NOT_FOUND")
    if session.get(PlayerBlock, (player.id, target_id)) is None:
        if session.scalar(select(func.count()).select_from(PlayerBlock).where(PlayerBlock.player_id == player.id)) >= 1000:
            raise HTTPException(409, "BLOCK_LIMIT_REACHED")
        session.add(PlayerBlock(player_id=player.id, blocked_id=target_id))
    from .news_models import Friendship
    low, high = sorted((player.id, target_id))
    session.execute(delete(Friendship).where(Friendship.low_id == low, Friendship.high_id == high))
    session.commit()
    return {"player_id": target_id, "blocked": True}


@router.delete("/v1/community/blocks/{target_id}")
def unblock(target_id: UUID, session: DB, player: Auth):
    session.execute(delete(PlayerBlock).where(PlayerBlock.player_id == player.id, PlayerBlock.blocked_id == str(target_id)))
    session.commit()
    return {"player_id": str(target_id), "blocked": False}


@router.get("/community-rules", include_in_schema=False)
def public_rules():
    from .privacy_pages import page
    return page("Public sharing rules", f"<p>Version {TERMS_VERSION}</p>" + "".join(
        f"<p>{escape(paragraph)}</p>" for paragraph in TERMS.splitlines()[1:]))
