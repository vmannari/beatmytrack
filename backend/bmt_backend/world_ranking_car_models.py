"""Version-two car ladders. Every published class belongs to one atomic snapshot."""
from sqlalchemy import JSON, BigInteger, ForeignKey, Index, Integer, LargeBinary, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class CarCircuit(Base):
    __tablename__ = "world_car_circuits"
    circuit_id: Mapped[int] = mapped_column(Integer, ForeignKey("world_circuits.id"), primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    contract_key: Mapped[str] = mapped_column(String(64))
    tracks: Mapped[list] = mapped_column(JSON)
    participation_bps: Mapped[int] = mapped_column(Integer, default=10000)
    population_units: Mapped[int] = mapped_column(BigInteger, default=0)
    population_snapshot: Mapped[int | None] = mapped_column(Integer)
    weights_locked: Mapped[bool] = mapped_column(default=False)


class CarEntry(Base):
    __tablename__ = "world_car_entries"
    circuit_id: Mapped[int] = mapped_column(Integer, ForeignKey("world_circuits.id"), primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    player_key: Mapped[int] = mapped_column(BigInteger, ForeignKey("world_ranking_players.key"), primary_key=True)
    group_id: Mapped[str] = mapped_column(String(36), ForeignKey("rivalry_groups.id"), index=True)


class CarWeek(Base):
    __tablename__ = "world_car_weeks"
    snapshot_id: Mapped[int] = mapped_column(Integer, ForeignKey("world_ranking_snapshots.id"), primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    field_size: Mapped[int] = mapped_column(Integer, default=0)
    ranked_count: Mapped[int] = mapped_column(Integer, default=0)
    participation_bps: Mapped[int] = mapped_column(Integer, default=10000)
    strength_bps: Mapped[int] = mapped_column(Integer, default=10000)
    rating_histogram: Mapped[list] = mapped_column(JSON, default=list)


class CarAward(Base):
    __tablename__ = "world_car_awards"
    __table_args__ = (Index("ix_world_car_award_history", "branch_id", "player_key", "circuit_id"),
        Index("ix_world_car_award_members", "branch_id", "circuit_id", "player_key", "vehicle_id"))
    branch_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    circuit_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    player_key: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    points: Mapped[int] = mapped_column(SmallInteger)
    weekly_place: Mapped[int] = mapped_column(Integer)
    tie_count: Mapped[int] = mapped_column(Integer)
    rating: Mapped[int] = mapped_column(Integer, default=1500)
    rated_weeks: Mapped[int] = mapped_column(Integer, default=0)


class CarStanding(Base):
    __tablename__ = "world_car_standings"
    __table_args__ = (
        Index("ix_world_car_standing_members", "snapshot_id", "player_key", "vehicle_id"),
        Index("ix_world_car_page", "snapshot_id", "vehicle_id", "world_rank", "player_key"),
        Index("ix_world_car_country", "snapshot_id", "vehicle_id", "country", "country_rank", "player_key"),
        Index("ix_world_car_season", "snapshot_id", "vehicle_id", "season_rank", "player_key"))
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    player_key: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    total: Mapped[int] = mapped_column(Integer)
    world_rank: Mapped[int | None] = mapped_column(Integer)
    country: Mapped[str] = mapped_column(String(2))
    country_rank: Mapped[int | None] = mapped_column(Integer)
    season_points: Mapped[int] = mapped_column(Integer)
    season_rank: Mapped[int | None] = mapped_column(Integer)
    rating: Mapped[int] = mapped_column(Integer)
    rated_weeks: Mapped[int] = mapped_column(Integer)
    last_rated_week: Mapped[int] = mapped_column(BigInteger)


class CarInput(Base):
    __tablename__ = "world_car_work_inputs"
    __table_args__ = (Index("ix_world_car_input_members", "snapshot_id", "player_key", "vehicle_id"),)
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    player_key: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    t0: Mapped[int] = mapped_column(Integer)
    t1: Mapped[int] = mapped_column(Integer)
    t2: Mapped[int] = mapped_column(Integer)
    t3: Mapped[int] = mapped_column(Integer)
    t4: Mapped[int] = mapped_column(Integer)
    country: Mapped[str] = mapped_column(String(2))
    rating: Mapped[int] = mapped_column(Integer, default=1500)
    strength_rating: Mapped[int] = mapped_column(Integer, default=1500)
    rated_weeks: Mapped[int] = mapped_column(Integer, default=0)


class CarPlace(Base):
    __tablename__ = "world_car_work_places"
    __table_args__ = (Index("ix_world_car_place_members", "snapshot_id", "player_key", "vehicle_id", "slot"),)
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    slot: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_key: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    place2: Mapped[int] = mapped_column(Integer)


class CarWeekly(Base):
    __tablename__ = "world_car_work_weekly"
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    player_key: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    sum2: Mapped[int] = mapped_column(BigInteger)
    k0: Mapped[int] = mapped_column(Integer)
    k1: Mapped[int] = mapped_column(Integer)
    k2: Mapped[int] = mapped_column(Integer)
    k3: Mapped[int] = mapped_column(Integer)
    k4: Mapped[int] = mapped_column(Integer)


class CarWork(Base):
    __tablename__ = "world_car_work_standings"
    __table_args__ = (Index("ix_world_car_work_members", "snapshot_id", "player_key", "vehicle_id"),)
    snapshot_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    player_key: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    country: Mapped[str] = mapped_column(String(2))
    total: Mapped[int] = mapped_column(Integer)
    season_points: Mapped[int] = mapped_column(Integer)
    world_key: Mapped[bytes] = mapped_column(LargeBinary(512))
    season_key: Mapped[bytes] = mapped_column(LargeBinary(512))
    rating: Mapped[int] = mapped_column(Integer, default=1500)
    rated_weeks: Mapped[int] = mapped_column(Integer, default=0)
    last_rated_week: Mapped[int] = mapped_column(BigInteger, default=0)
