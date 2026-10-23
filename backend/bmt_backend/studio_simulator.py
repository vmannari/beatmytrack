"""Deterministic development history imported into ordinary application tables.

Operator-only CLI, not an HTTP endpoint. No credentials, external provider calls,
mail, notifications or changes to existing identities are involved. Historical
race imports reuse accepted immutable recordings and their exact timing, never
invent a proof or alter the verifier. Normal telemetry projectors build reports.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import re
from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import exists, select, text

from . import network_health, race_statistics, telemetry
from .config import Settings
from .db import make_engine, make_session_factory
from .identity_models import Identity, Player
from .product_analytics import project_pending
from .studio_platform_models import AnalysisState, StudioCoinEntry
from .telemetry_models import ProductEvent
from .track_models import (
    Board,
    LapPersonalBest,
    OperationState,
    PersonalBest,
    Run,
    RunTicket,
    Track,
    TrackVersion,
    digest,
    now,
)

DAY = 86400
VERSION = 1
FIRST = (
    "Alex",
    "Maya",
    "Leo",
    "Nora",
    "Kai",
    "Emma",
    "Noah",
    "Luna",
    "Aria",
    "Liam",
    "Finn",
    "Sofia",
    "Hugo",
    "Ella",
    "Mika",
    "Zoe",
    "Theo",
    "Iris",
    "Ava",
    "Luca",
    "Sami",
    "Mila",
    "Otto",
    "Ruby",
)
LAST = (
    "Apex",
    "Drift",
    "Rally",
    "Lane",
    "Storm",
    "Summit",
    "Ridge",
    "Vale",
    "Brook",
    "Stone",
    "Reed",
    "Park",
    "Fox",
    "Lake",
    "River",
    "West",
    "Snow",
    "Cross",
    "Dune",
    "North",
    "Ash",
    "Cove",
    "Pine",
    "Coast",
    "Swift",
)
DEVICES = (
    ("android", "Samsung Galaxy A13", "13", "android_arm64", "gl_compatibility", 1280, 720),
    ("android", "OnePlus Nord 2", "14", "android_arm64", "mobile", 1600, 900),
    ("android", "Google Pixel 7", "15", "android_arm64", "mobile", 1920, 1080),
    ("ios", "iPhone 13", "18", "other", "mobile", 1560, 720),
    ("windows", "Windows gaming PC", "11", "desktop", "forward_plus", 1920, 1080),
)
BUILDS = ("0.59.0", "0.59.1", "0.59.2")


def identity(*parts):
    """Stable UUID4-shaped receipt IDs, accepted by the real telemetry contracts."""
    return str(
        UUID(bytes=hashlib.sha256(json.dumps(parts, separators=(",", ":")).encode()).digest()[:16], version=4)
    )


@dataclass(frozen=True)
class Plan:
    dataset: str = "studio-october"
    players: int = 600
    days: int = 60
    seed: int = 1701
    anchor: int = 0

    def validate(self):
        if not re.fullmatch(r"[a-z][a-z0-9-]{2,39}", self.dataset):
            raise ValueError("Dataset must be a stable 3â€“40 character operator identifier")
        if not 10 <= self.players <= 2000 or not 8 <= self.days <= 90 or not 0 <= self.seed < 2**31:
            raise ValueError("Use10â€“2000 players,8â€“90 days and a bounded seed")
        if self.players * self.days > 180000 or not DAY < self.anchor <= now():
            raise ValueError("History exceeds the bounded import budget or anchor is in the future")
        return self

    @property
    def first_day(self):
        return self.anchor // DAY - self.days + 1

    def person(self, index):
        rng = random.Random(f"{self.seed}:person:{index}")
        # An established base plus a recent acquisition wave, all ordinary players.
        signup = 0 if index < self.players // 10 else rng.randrange(self.days)
        kind = rng.choices(("tourist", "regular", "enthusiast", "creator"), (36, 38, 19, 7))[0]
        return {
            "id": identity(self.dataset, "player", index),
            "name": FIRST[index % len(FIRST)]
            + " "
            + LAST[(index // len(FIRST)) % len(LAST)]
            + (" " + str(index // 600 + 1) if index >= 600 else ""),
            "signup": self.first_day + signup,
            "kind": kind,
            "device": rng.randrange(len(DEVICES)),
            "country": rng.choice(("FI", "US", "DE", "GB", "BR", "JP", "FR", "CA", "AU", "SE")),
            "payer": rng.random() < 0.14,
        }


def rng_for(plan, *parts):
    return random.Random(f"{plan.seed}:" + ":".join(map(str, parts)))


def active(plan, person, day):
    age = day - person["signup"]
    if age < 0:
        return False
    if age == 0:
        return True
    rng = rng_for(plan, "active", person["id"], day)
    strength = {"tourist": 0.28, "regular": 0.72, "enthusiast": 0.94, "creator": 0.86}[person["kind"]]
    decay = {"tourist": 2.5, "regular": 32, "enthusiast": 140, "creator": 90}[person["kind"]]
    weekend = 1.15 if (day + 3) % 7 in (5, 6) else 1
    return rng.random() < strength * math.exp(-age / decay) * weekend


def build_for(plan, person, day):
    remaining = plan.anchor // DAY - day
    holdout = int(person["id"].replace("-", "")[:4], 16) % 5 == 0
    return BUILDS[0] if remaining > 8 or holdout else BUILDS[1] if remaining > 2 else BUILDS[2]


def race_package(rng, device, build, race_id, version, elapsed, outcome, points):
    _platform, model, os_version, device_class, renderer, w, h = device
    bad = build == BUILDS[1] and device == DEVICES[0]
    weights = (
        (0.01, 0.03, 0.62, 0.20, 0.09, 0.035, 0.01, 0.005)
        if not bad
        else (0.005, 0.005, 0.24, 0.20, 0.20, 0.21, 0.10, 0.04)
    )
    frames = max(60, min(90000, elapsed // (26 if bad else 17)))
    buckets = [int(frames * p) for p in weights]
    buckets[2] += frames - sum(buckets)
    # Sample actual authored outline positions, retaining bounded cells and segments.
    cells = Counter(
        (max(-5000, min(5000, int(p[0] // 20))), max(-5000, min(5000, int(p[1] // 20)))) for p in points[:48]
    )
    rows = [[x, y, n, min(n, 1 if bad and rng.random() < 0.55 else 0)] for (x, y), n in cells.items()]
    samples = sum(row[2] for row in rows)
    segments = [
        [i, n, min(n, n // 2 if bad else n // 12)]
        for i, n in enumerate([samples // 8 + (i < samples % 8) for i in range(8)])
        if n
    ]
    result = {
        "schema_version": 3,
        "race_id": race_id,
        "track_version_id": version,
        "outcome": outcome,
        "elapsed_ms": elapsed,
        "device_class": device_class,
        "device_model": model,
        "os_version": os_version,
        "frame_buckets": buckets,
        "position_samples": samples,
        "dropped_samples": 0,
        "cells": rows,
        "segments": segments,
        "render_context": {
            "schema_version": 1,
            "renderer": renderer,
            "car_detail": "full",
            "viewport_width": w,
            "viewport_height": h,
            "scale_percent": 100,
            "frame_limit": 60,
            "vsync": "enabled",
            "refresh_hz": 60,
        },
        "render_context_changed": False,
    }
    return race_statistics.validate(result)


def network_package(device, category, bad):
    result = {field: 0 for field in network_health.COUNTERS}
    result.update(
        schema_version=1,
        category=category,
        device_model=device[1],
        os_version=device[2],
        attempts=10,
        successes=8 if bad else 10,
        retries=2 if bad else 0,
        request_body_bytes=14000,
        response_body_bytes=92000,
        total_ms=10000 if bad else 1800,
        queue_ms=100,
        http_ms=9500 if bad else 1500,
        encode_ms=100,
        decode_ms=100,
    )
    for field, size in network_health.ARRAYS.items():
        result[field] = [0] * size
    result["latency_buckets"][5 if bad else 3] = 10
    result["queue_buckets"][0] = 10
    result["http_buckets"][5 if bad else 3] = 10
    result["status_buckets"][1] = 8 if bad else 10
    if bad:
        result["status_buckets"][0] = 2
    result["error_buckets"][0] = result["successes"]
    if bad:
        result["error_buckets"][5] = 2
    result["method_buckets"][1 if category == "score_upload" else 0] = 10
    if category == "score_upload":
        result["upload_age_samples"] = 10
        result["upload_age_buckets"][1 if bad else 0] = 10
    return network_health.validate("network_summary", result)


class Simulator:
    def __init__(self, factory, settings, plan, *, templates=None):
        if settings.environment != "development" and settings.environment != "test":
            raise ValueError("Studio simulator is restricted to development/test environments")
        self.factory, self.settings, self.plan = factory, settings, plan.validate()
        self.key = "studio-simulator:" + plan.dataset
        self.templates = templates
        self.totals = Counter()

    def initialise(self):
        p = self.plan
        with self.factory() as db:
            if db.bind.dialect.name == "postgresql":
                db.execute(
                    text("SELECT pg_advisory_xact_lock(:key)"), {"key": int(digest(self.key)[:15], 16)}
                )
            row = db.get(OperationState, self.key)
            if row:
                if row.details["plan"] != asdict(p):
                    raise ValueError(
                        "Dataset plan is immutable; reuse its recorded anchor or choose a new dataset"
                    )
                self.totals.update(row.details.get("totals", {}))
                return row.details["cursor"]
            people = [p.person(i) for i in range(p.players)]
            if db.scalar(
                select(Player.id).where(Player.id.in_([person["id"] for person in people])).limit(1)
            ):
                raise ValueError("Simulator identity collision")
            for person in people:
                db.add(
                    Player(
                        id=person["id"],
                        display_name=person["name"],
                        country_code=person["country"],
                        analytics_enabled=True,
                        is_test_driver=False,
                        created_at=person["signup"] * DAY + 100,
                    )
                )
            db.flush()
            for i, person in enumerate(people):
                db.add(
                    Identity(
                        id=identity(p.dataset, "identity", i),
                        player_id=person["id"],
                        provider="development",
                        subject=p.dataset + ":" + str(i),
                    )
                )
            db.flush()
            state = db.get(AnalysisState, 1)
            state.started_at = min(state.started_at, p.first_day * DAY)
            db.add(
                OperationState(
                    id=self.key,
                    updated_at=now(),
                    details={"version": VERSION, "plan": asdict(p), "cursor": 0, "totals": {}},
                )
            )
            db.commit()
        return 0

    def load_templates(self):
        if self.templates is not None:
            return self.templates
        with self.factory() as db:
            journal = db.get(OperationState, self.key)
            if journal and journal.details.get("templates"):
                self.templates = journal.details["templates"]
                return self.templates
            boards = db.scalars(
                select(Board)
                .join(TrackVersion, TrackVersion.id == Board.version_id)
                .join(Track, Track.id == TrackVersion.track_id)
                .where(
                    TrackVersion.state == "published",
                    exists(select(Run.id).where(Run.board_id == Board.id, Run.status == "verified")),
                    Track.hidden.is_(False),
                )
                .order_by(Board.id)
                .limit(12)
            ).all()
            result = []
            for board in boards:
                manifest = {k: v for k, v in board.manifest.items() if k != "test_population"}
                if manifest.get("purpose") or manifest.get("laps", 5) != 5:
                    continue
                version = db.get(TrackVersion, board.version_id)
                rows = db.scalars(
                    select(Run)
                    .where(Run.board_id == board.id, Run.status == "verified", Run.time_ticks > 0)
                    .order_by(Run.id)
                    .limit(6)
                ).all()
                normal_id = digest({"version_id": version.id, **manifest})
                if db.get(Board, normal_id) is None:
                    db.add(
                        Board(
                            id=normal_id,
                            version_id=version.id,
                            vehicle_id=board.vehicle_id,
                            manifest=manifest,
                        )
                    )
                for run in rows:
                    if not run.lap_ticks or len(run.lap_ticks) != 5 or sum(run.lap_ticks) != run.time_ticks:
                        continue
                    result.append(
                        {
                            "board_id": normal_id,
                            "version_id": version.id,
                            "vehicle": board.vehicle_id,
                            "manifest": manifest,
                            "replay_hash": run.replay_hash,
                            "ghost_hash": run.ghost_hash,
                            "time_ticks": run.time_ticks,
                            "lap_ticks": list(run.lap_ticks),
                            "source_run_id": run.id,
                            "points": (version.discovery or {}).get("points", []),
                            "biome": (version.discovery or {}).get("theme", "pine"),
                        }
                    )
            if journal:
                journal.details = {**journal.details, "templates": result}
            db.commit()
        if not result:
            raise ValueError("No accepted five-lap recording is available; import a verified race first")
        self.templates = result
        return result

    def events(self, person, day, session_number):
        p = self.plan
        rng = rng_for(p, "session", person["id"], day, session_number)
        device = DEVICES[person["device"]]
        build = build_for(p, person, day)
        cutoff = min((day + 1) * DAY - 60, p.anchor - 60)
        start = day * DAY + max(180, min(20 * 3600, cutoff - day * DAY - 3000))
        if cutoff <= start:
            return [], []
        start = max(day * DAY + 120, start - rng.randrange(min(4 * 3600, start - day * DAY)))
        stamp = start
        seq = 0
        rows = []
        races = []
        session_id = identity(p.dataset, person["id"], day, session_number)

        def emit(name, props=None, *, server=False, at=None, entity=None):
            nonlocal seq, stamp
            seq += 1
            stamp = min(cutoff, stamp + rng.randrange(1, 5)) if at is None else min(cutoff, at)
            props = props or {}
            if not server:
                props = telemetry.properties(name, props)
            key = identity(p.dataset, session_id, seq, name)
            row = {
                "id": key,
                "client_id": None if server else key,
                "entity_id": entity,
                "player_id": person["id"],
                "is_test_driver": False,
                "source": "server" if server else "client",
                "name": name,
                "occurred_at": stamp,
                "received_at": stamp + 1,
                "session_id": session_id,
                "install_id": identity(p.dataset, person["id"], "install"),
                "seq": seq,
                "monotonic_ms": max(0, (stamp - start) * 1000),
                "build_id": build,
                "platform": device[0],
                "clock_quality": "server" if server else "server_estimate",
                "properties": props,
                "processed_at": None,
                "compacted": False,
            }
            row["payload_hash"] = digest(row)
            rows.append(row)

        first = day == person["signup"] and session_number == 0
        if first:
            emit("app_first_open")
        emit("session_started", {"reason": "launch" if first else "resume"})
        if first and rng.random() < 0.08:
            return rows, races
        emit("menu_ready")
        if first and rng.random() < 0.12:
            emit("session_backgrounded", {"foreground_ms": 12000})
            return rows, races
        template = rng.choice(self.load_templates())
        track = {
            "track_version_id": template["version_id"],
            "car_id": template["vehicle"],
            "biome": template["biome"],
            "mode": "free",
        }
        if track["biome"] not in telemetry.BIOMES:
            track["biome"] = "pine"
        for position, car in enumerate(sorted(telemetry.CARS)):
            emit("car_exposed", {"car_id": car, "position": position})
        emit("car_selected", {"car_id": rng.choice(sorted(telemetry.CARS))})
        emit("track_exposed", track)
        emit("track_selected", track)
        emit("car_selected", {"car_id": template["vehicle"]})
        for attempt in range(rng.randint(1, 3) if person["kind"] != "tourist" else 1):
            if stamp + 300 >= cutoff:
                break
            race_id = identity(p.dataset, session_id, "race", attempt)
            ticket = identity(p.dataset, session_id, "ticket", attempt)
            context = {**track, "ticket_id": ticket}
            emit("race_attempt", context)
            if first and attempt == 0 and rng.random() < 0.08:
                break
            created = stamp
            emit("race_started", context)
            bad = build == BUILDS[1] and person["device"] == 0
            outcome = (
                rng.choice(("abandoned", "restarted"))
                if rng.random() < (0.38 if bad else 0.13)
                else "finished"
            )
            elapsed = (
                template["time_ticks"] * 1000 // 120 if outcome == "finished" else rng.randint(16000, 50000)
            )
            available = (cutoff - stamp - 10) * 1000
            if outcome == "finished" and elapsed > available:
                outcome = "abandoned"
            elapsed = min(elapsed, available)
            if elapsed < 1000:
                break
            emit(
                "race_finished" if outcome == "finished" else "race_abandoned",
                {
                    **context,
                    "reason": "restart"
                    if outcome == "restarted"
                    else "exit"
                    if outcome == "abandoned"
                    else "finished",
                },
                at=stamp + elapsed // 1000,
            )
            emit(
                "race_statistics",
                race_package(
                    rng, device, build, race_id, template["version_id"], elapsed, outcome, template["points"]
                ),
            )
            if outcome == "finished":
                submitted = stamp
                emit(
                    "race_accepted",
                    {
                        "track_version_id": template["version_id"],
                        "car_id": template["vehicle"],
                        "lap_count": 5,
                    },
                    server=True,
                    entity=race_id,
                )
                races.append(
                    {
                        "id": race_id,
                        "ticket": ticket,
                        "player": person["id"],
                        "ticket_created": created,
                        "created": submitted,
                        "finished": stamp,
                        "template": template,
                    }
                )
            elif outcome == "restarted":
                emit("race_retried", {**context, "reason": "restart"})
            emit("network_summary", network_package(device, "score_upload", bad))
            if bad and rng.random() < 0.12:
                emit("process_exit", {"exit_reason": rng.choice((4, 6)), "device_class": device[3]})
        if rng.random() < 0.35:
            product = rng.choice(sorted(telemetry.PRODUCTS))
            emit("store_opened")
            emit("offer_exposed", {"product_id": product})
            if person["payer"] and rng.random() < 0.45:
                emit("purchase_requested", {"product_id": product})
        if person["kind"] == "creator" and rng.random() < 0.3:
            emit("publish_requested", {"biome": track["biome"], "reason": "publish"})
        emit("network_summary", network_package(device, "discovery", False))
        foreground = min(DAY * 1000, max(15000, (stamp - start) * 1000))
        if day == p.anchor // DAY and cutoff - stamp > 90:
            emit("session_heartbeat", {"foreground_ms": 60000}, at=cutoff - 5)
        emit("session_backgrounded", {"foreground_ms": foreground})
        return rows, races

    def import_race(self, db, data):
        """Reused accepted recording, exact timings, ordinary PB/reward authority."""
        t = data["template"]
        player = data["player"]
        db.add(
            RunTicket(
                id=data["ticket"],
                player_id=player,
                board_id=t["board_id"],
                created_at=data["ticket_created"],
                expires_at=data["ticket_created"] + 3600,
            )
        )
        db.flush()
        run = Run(
            id=data["id"],
            ticket_id=data["ticket"],
            player_id=player,
            board_id=t["board_id"],
            replay_hash=t["replay_hash"],
            ghost_hash=t["ghost_hash"],
            status="verified",
            created_at=data["created"],
            finished_at=data["finished"],
            attempts=1,
            time_ticks=t["time_ticks"],
            lap_ticks=t["lap_ticks"],
        )
        db.add(run)
        db.flush()
        old = db.get(PersonalBest, (t["board_id"], player))
        lap = db.get(LapPersonalBest, (t["board_id"], player))
        previous = (old.time_ticks if old else 0, lap.time_ticks if lap else 0)
        if old is None:
            db.add(
                PersonalBest(
                    board_id=t["board_id"],
                    player_id=player,
                    run_id=run.id,
                    time_ticks=run.time_ticks,
                    achieved_at=data["finished"],
                )
            )
        elif run.time_ticks < old.time_ticks:
            old.run_id, old.time_ticks, old.achieved_at = run.id, run.time_ticks, data["finished"]
        lap_ticks = min(run.lap_ticks[1:])
        lap_index = run.lap_ticks.index(lap_ticks, 1)
        if lap is None:
            db.add(
                LapPersonalBest(
                    board_id=t["board_id"],
                    player_id=player,
                    run_id=run.id,
                    time_ticks=lap_ticks,
                    lap_index=lap_index,
                    achieved_at=data["finished"],
                    source_created_at=data["created"],
                )
            )
        elif lap_ticks < lap.time_ticks:
            lap.run_id, lap.time_ticks, lap.lap_index, lap.achieved_at, lap.source_created_at = (
                run.id,
                lap_ticks,
                lap_index,
                data["finished"],
                data["created"],
            )
        db.flush()
        from .economy import accept_verified

        accept_verified(db, run, previous)
        # The historical import carries historical ledger dates as well as run dates.
        entries = db.scalars(
            select(StudioCoinEntry).where(
                StudioCoinEntry.player_id == player,
                StudioCoinEntry.reference.in_(("opening", "run/" + run.id)),
            )
        ).all()
        for entry in entries:
            entry.created_at = min(entry.created_at, data["finished"])
        self.totals["accepted_races"] += 1

    def history(self, *, stop_after=None, progress=print):
        cursor = self.initialise()
        self.load_templates()
        p = self.plan
        total = p.days * ((p.players + 24) // 25)
        steps = 0
        while cursor < total:
            day = p.first_day + cursor // ((p.players + 24) // 25)
            offset = (cursor % ((p.players + 24) // 25)) * 25
            with self.factory() as db:
                journal = db.scalar(
                    select(OperationState).where(OperationState.id == self.key).with_for_update()
                )
                if journal.details["cursor"] != cursor:
                    raise RuntimeError("Another process advanced this dataset; resume from its saved cursor")
                events = []
                for i in range(offset, min(p.players, offset + 25)):
                    person = p.person(i)
                    if not active(p, person, day):
                        continue
                    for number in range(
                        1 + int(person["kind"] == "enthusiast" and rng_for(p, "extra", i, day).random() < 0.3)
                    ):
                        rows, races = self.events(person, day, number)
                        events.extend(rows)
                        self.totals["sessions"] += bool(rows)
                        for race in races:
                            self.import_race(db, race)
                if events:
                    from .studio_simulator_scenarios import purchase_event

                    for entry in events:
                        if entry["name"] == "purchase_requested":
                            purchase_event(db, p, entry)
                    db.execute(
                        telemetry.insert_for(db, ProductEvent)
                        .values(events)
                        .on_conflict_do_nothing(index_elements=["id"])
                    )
                    self.totals["events"] += len(events)
                    from .telemetry_queue import register_ids
                    register_ids(db, [e["id"] for e in events])
                cursor += 1
                steps += 1
                journal.details = {
                    **journal.details,
                    "version": VERSION,
                    "plan": asdict(p),
                    "cursor": cursor,
                    "totals": dict(self.totals),
                }
                journal.updated_at = now()
                db.commit()
            if cursor % ((p.players + 24) // 25) == 0:
                self.project(limit_batches=30)
                progress(
                    json.dumps(
                        {
                            "dataset": p.dataset,
                            "day": datetime.fromtimestamp(day * DAY, timezone.utc).date().isoformat(),
                            "cursor": cursor,
                            "batches": total,
                            **self.totals,
                        }
                    ),
                    flush=True,
                )
            if stop_after and steps >= stop_after:
                break
        if cursor == total:
            self.project()
            self.workspaces()
        return {"cursor": cursor, "batches": total, "complete": cursor == total, **self.totals}

    def project(self, limit_batches=10000):
        for _ in range(limit_batches):
            value = project_pending(
                self.factory,
                limit=500,
                raw_days=self.settings.telemetry_raw_days,
                fact_days=self.settings.telemetry_fact_days,
            )
            if not value["pending"]:
                return

    def workspaces(self):
        """Durable normal workflow records, never real notification delivery."""
        from .studio_simulator_scenarios import seed_workspaces

        seed_workspaces(self)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", default="studio-october")
    parser.add_argument("--players", type=int, default=600)
    parser.add_argument("--days", type=int, default=60)
    parser.add_argument("--seed", type=int, default=1701)
    parser.add_argument("--anchor", type=int)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--max-batches", type=int)
    args = parser.parse_args()
    settings = Settings.from_env()
    if settings.environment not in ("development", "test"):
        parser.error("Development/test environment required")
    engine = make_engine(settings.database_url, settings)
    factory = make_session_factory(engine)
    try:
        with factory() as db:
            old = db.get(OperationState, "studio-simulator:" + args.dataset)
            anchor = args.anchor or (old.details["plan"]["anchor"] if old else now())
        plan = Plan(args.dataset, args.players, args.days, args.seed, anchor).validate()
        if not args.apply:
            print(
                json.dumps(
                    {
                        "plan": asdict(plan),
                        "first_day": plan.first_day,
                        "ordinary_players": True,
                        "apply": False,
                    }
                )
            )
            return
        result = Simulator(factory, settings, plan).history(stop_after=args.max_batches)
        print("STUDIO_SIMULATOR_RESULT=" + json.dumps({"plan": asdict(plan), **result}))
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
