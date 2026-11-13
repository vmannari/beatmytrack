"""Small published ranking records; wide numeric work is temporary and bounded."""
from sqlalchemy import (
    JSON,
    BigInteger,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    SmallInteger,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base

KEY = BigInteger().with_variant(Integer, "sqlite")


class RankingControl(Base):
    __tablename__ = "world_ranking_control"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    launch_week: Mapped[int] = mapped_column(BigInteger)
    published_id: Mapped[int | None] = mapped_column(Integer)
    previous_id: Mapped[int | None] = mapped_column(Integer)
    running_branch: Mapped[int] = mapped_column(Integer)


class RankingPlayer(Base):
    __tablename__ = "world_ranking_players"
    key: Mapped[int] = mapped_column(KEY, primary_key=True, autoincrement=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), unique=True)


class Circuit(Base):
    __tablename__ = "world_circuits"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    week_start: Mapped[int] = mapped_column(BigInteger, unique=True)
    contract_key: Mapped[str] = mapped_column(String(64))
    policy: Mapped[str] = mapped_column(String(40))
    tracks: Mapped[list] = mapped_column(JSON)
    original_snapshot: Mapped[int | None] = mapped_column(Integer)


class CircuitEntry(Base):
    __tablename__ = "world_circuit_entries"
    circuit_id: Mapped[int] = mapped_column(ForeignKey("world_circuits.id"), primary_key=True)
    player_key: Mapped[int] = mapped_column(ForeignKey("world_ranking_players.key"), primary_key=True)
    group_id: Mapped[str] = mapped_column(ForeignKey("rivalry_groups.id"), index=True)


class RankingBranch(Base):
    __tablename__ = "world_ranking_branches"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    mode: Mapped[str] = mapped_column(String(16), default="active")
    next_week: Mapped[int] = mapped_column(BigInteger)
    through_week: Mapped[int | None] = mapped_column(BigInteger)
    last_snapshot: Mapped[int | None] = mapped_column(Integer)
    snapshot_id: Mapped[int | None] = mapped_column(Integer)
    phase: Mapped[str] = mapped_column(String(32), default="idle")
    cursor: Mapped[int] = mapped_column(BigInteger, default=0)
    part: Mapped[int] = mapped_column(Integer, default=0)
    lease_token: Mapped[str] = mapped_column(String(36), default="")
    lease_until: Mapped[int] = mapped_column(BigInteger, default=0)
    failure: Mapped[str] = mapped_column(String(160), default="")
    reason: Mapped[str] = mapped_column(String(500), default="")


class RankingSnapshot(Base):
    __tablename__ = "world_ranking_snapshots"
    __table_args__ = (UniqueConstraint("branch_id", "week_start"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    branch_id: Mapped[int] = mapped_column(ForeignKey("world_ranking_branches.id"))
    circuit_id: Mapped[int] = mapped_column(ForeignKey("world_circuits.id"))
    week_start: Mapped[int] = mapped_column(BigInteger)
    previous_id: Mapped[int | None] = mapped_column(Integer)
    field_size: Mapped[int] = mapped_column(Integer, default=0)
    ranked_count: Mapped[int] = mapped_column(Integer, default=0)
    season_qualifying_weeks: Mapped[int] = mapped_column(SmallInteger, default=0)
    state: Mapped[str] = mapped_column(String(16), default="building")
    published_at: Mapped[int | None] = mapped_column(BigInteger)


class RankingAward(Base):
    __tablename__ = "world_ranking_awards"
    branch_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    circuit_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_key: Mapped[int] = mapped_column(KEY, primary_key=True)
    points: Mapped[int] = mapped_column(SmallInteger)
    weekly_place: Mapped[int] = mapped_column(Integer)


class RankingStanding(Base):
    __tablename__ = "world_ranking_standings"
    __table_args__ = (
        Index("ix_world_standing_page", "snapshot_id", "world_rank", "player_key"),
        Index("ix_world_standing_country", "snapshot_id", "country", "country_rank", "player_key"),
        Index("ix_world_standing_season", "snapshot_id", "season_rank", "player_key"))
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_key: Mapped[int] = mapped_column(KEY, primary_key=True)
    total: Mapped[int] = mapped_column(SmallInteger)
    world_rank: Mapped[int] = mapped_column(Integer)
    country: Mapped[str] = mapped_column(String(2))
    country_rank: Mapped[int | None] = mapped_column(Integer)
    season_points: Mapped[int] = mapped_column(SmallInteger)
    season_rank: Mapped[int | None] = mapped_column(Integer)


class RankingCareer(Base):
    __tablename__ = "world_ranking_careers"
    branch_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_key: Mapped[int] = mapped_column(KEY, primary_key=True)
    generation: Mapped[int] = mapped_column(Integer, primary_key=True)
    peak_rank: Mapped[int] = mapped_column(Integer)
    peak_week: Mapped[int] = mapped_column(BigInteger)
    peak_field: Mapped[int] = mapped_column(Integer)
    weeks_top100: Mapped[int] = mapped_column(Integer, default=0)
    weeks_no1: Mapped[int] = mapped_column(Integer, default=0)
    victories: Mapped[int] = mapped_column(Integer, default=0)
    season_titles: Mapped[int] = mapped_column(Integer, default=0)


class RankingArchive(Base):
    __tablename__ = "world_ranking_archives"
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    kind: Mapped[str] = mapped_column(String(8), primary_key=True)
    part: Mapped[int] = mapped_column(Integer, primary_key=True)
    digest: Mapped[str] = mapped_column(String(64), index=True)
    first_key: Mapped[int] = mapped_column(BigInteger)
    last_key: Mapped[int] = mapped_column(BigInteger)
    count: Mapped[int] = mapped_column(Integer)


class RankingCorrection(Base):
    __tablename__ = "world_ranking_corrections"
    command_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    circuit_id: Mapped[int] = mapped_column(Integer)
    player_key: Mapped[int] = mapped_column(BigInteger)  # zero means whole-week void
    reason: Mapped[str] = mapped_column(String(500))
    actor: Mapped[str] = mapped_column(String(120))
    created_at: Mapped[int] = mapped_column(BigInteger)
    __table_args__ = (Index("ix_world_correction_week", "circuit_id", "player_key"),)


class RankingInput(Base):
    __tablename__ = "world_work_inputs"
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_key: Mapped[int] = mapped_column(KEY, primary_key=True)
    t0: Mapped[int] = mapped_column(Integer)
    t1: Mapped[int] = mapped_column(Integer)
    t2: Mapped[int] = mapped_column(Integer)
    t3: Mapped[int] = mapped_column(Integer)
    t4: Mapped[int] = mapped_column(Integer)
    country: Mapped[str] = mapped_column(String(2))


class RankingPlace(Base):
    __tablename__ = "world_work_places"
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    slot: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    player_key: Mapped[int] = mapped_column(KEY, primary_key=True)
    place2: Mapped[int] = mapped_column(Integer)


class RankingWeeklyWork(Base):
    __tablename__ = "world_work_weekly"
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_key: Mapped[int] = mapped_column(KEY, primary_key=True)
    sum2: Mapped[int] = mapped_column(BigInteger)
    k0: Mapped[int] = mapped_column(Integer)
    k1: Mapped[int] = mapped_column(Integer)
    k2: Mapped[int] = mapped_column(Integer)
    k3: Mapped[int] = mapped_column(Integer)
    k4: Mapped[int] = mapped_column(Integer)


class RankingWork(Base):
    __tablename__ = "world_work_standings"
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_key: Mapped[int] = mapped_column(KEY, primary_key=True)
    country: Mapped[str] = mapped_column(String(2))
    total: Mapped[int] = mapped_column(SmallInteger, default=0)
    season_points: Mapped[int] = mapped_column(SmallInteger, default=0)
    world_key: Mapped[bytes] = mapped_column(LargeBinary, default=b"")
    season_key: Mapped[bytes] = mapped_column(LargeBinary, default=b"")
