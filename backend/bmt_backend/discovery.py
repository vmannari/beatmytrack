"""Discovery query contract and inert v2 endpoints.

The old snapshot tables remain mapped only for bounded cache retirement. V3
uses indexed changed-row history; no shipping handler builds catalogue vectors.
"""
from typing import Annotated

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import JSON, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .middleware import ParsedJSONRoute

router = APIRouter(route_class=ParsedJSONRoute,tags=["retired discovery"])

class DiscoverySnapshot(Base):
    __tablename__ = "discovery_snapshots"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    query_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[int] = mapped_column(Integer, nullable=False)
    version_ids: Mapped[list] = mapped_column(JSON, nullable=False)
    entry_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    __table_args__ = (Index("ix_discovery_snapshot_expiry", "expires_at"),)


class DiscoveryBudget(Base):
    __tablename__ = "discovery_budget"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    entries: Mapped[int] = mapped_column(Integer, nullable=False)
    snapshots: Mapped[int] = mapped_column(Integer, nullable=False)


class Query(BaseModel):
    model_config = ConfigDict(extra="forbid")
    search: str = Field("", max_length=80)
    search_kind: int = Field(0, ge=0, le=2)
    theme: str = Field("all", max_length=40)
    minimum_rating: float = Field(0, ge=0, le=5)
    age_days: int = Field(0, ge=0, le=36500)
    race_count: str = Field("any", pattern="^(any|low|medium|high)$")
    race_history: str = Field("any", pattern="^(any|raced|unraced)$")
    raced_ids: list[Annotated[str, Field(max_length=80)]] = Field(default_factory=list, max_length=50000)
    ids: list[Annotated[str, Field(max_length=80)]] | None = Field(None, max_length=50000)
    section: str = Field("all", pattern="^(all|favorites|saved)$")
    feed: str = Field("recommended", pattern="^(recommended|new|popular|rated|trending)$")
    sort: str = Field("recommended", pattern="^(recommended|name|creator|score|plays|new)$")
    cursor: str = Field("", max_length=400)
    offset: int | None = Field(None, ge=0)
    fresh: bool = False
    exclude: str = Field("", max_length=80)
    locate_version: str = Field("", max_length=36)


def _page(*_args, **_kwargs):
    raise HTTPException(426, "DISCOVERY_CLIENT_UPDATE_REQUIRED")


@router.post("/discovery/tracks")
def discover(query: Query):
    raise HTTPException(426, "DISCOVERY_CLIENT_UPDATE_REQUIRED")


@router.post("/discovery/random")
def choose_random(query: Query):
    raise HTTPException(426, "DISCOVERY_CLIENT_UPDATE_REQUIRED")
