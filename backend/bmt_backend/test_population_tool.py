"""Fill a development rivalry or seed a verified test field, then schedule attempts.

State files contain profiles, recordings and progress, never authentication keys.
Every attempt uses HTTP tickets/uploads and the existing verification worker.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import time
from pathlib import Path
from urllib.parse import urlparse

import requests

from .config import Settings
from .contracts import build_contract
from .test_driver_generator import DriverDidNotFinish, generate
from .track_models import digest

SCHEMA = "test-population-plan-v1"


def acquire_plan_lock(path):
    """OS-released advisory lock, so a crash never leaves a stale lock behind."""
    path.parent.mkdir(parents=True, exist_ok=True)
    stream = path.with_suffix(path.suffix + ".lock").open("a+b")
    if stream.tell() == 0:
        stream.write(b"0")
        stream.flush()
    stream.seek(0)
    try:
        if os.name == "nt":
            import msvcrt

            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl

            fcntl.flock(stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        stream.close()
        raise RuntimeError("Another scheduler is using this plan") from None
    return stream


def atomic_save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, allow_nan=False), encoding="utf-8")
    os.replace(temporary, path)


class API:
    def __init__(self, url, key):
        parsed = urlparse(url)
        if (
            parsed.username
            or parsed.password
            or parsed.query
            or parsed.fragment
            or not (
                parsed.scheme == "https"
                or parsed.scheme == "http"
                and parsed.hostname in ("127.0.0.1", "localhost")
            )
        ):
            raise ValueError("Use HTTPS or an explicit local loopback development service")
        if not key:
            raise ValueError("Set BMT_DEV_AUTH_KEY in the process environment")
        self.url, self.key, self.tokens = url.rstrip("/"), key, {}
        self.http = requests.Session()
        bootstrap = self.call("GET", "/bootstrap")
        if bootstrap.get("test_drivers") is not True or bootstrap.get("development_auth") is not True:
            raise ValueError("Service must explicitly enable development auth and test drivers")

    def call(self, method, path, body=None, subject=None, idempotency=None, operator=False):
        headers = {}
        if operator:
            headers["X-Dev-Auth-Key"] = self.key
        if subject:
            if subject not in self.tokens or self.tokens[subject][1] <= time.time() + 30:
                login = self.call(
                    "POST", "/auth/development", {"subject": subject, "display_name": subject}, operator=True
                )
                self.tokens[subject] = (login["access_token"], time.time() + login["expires_in"])
            headers["Authorization"] = "Bearer " + self.tokens[subject][0]
        if idempotency:
            headers["Idempotency-Key"] = idempotency
        response = self.http.request(method, self.url + "/v1" + path, json=body, headers=headers, timeout=120)
        if not response.ok:
            # Do not print the response request: it contains credentials.
            try:
                detail = response.json().get("detail", "Request failed")
            except ValueError:
                detail = "Service unavailable"
            raise RuntimeError(f"HTTP {response.status_code}: {str(detail)[:200]}")
        return response.json()


def schedule(traits, week_start, ends_at, instant=False):
    """Local UTC activity window, quiet profiles and diminishing attempt budgets."""
    rng = random.Random(traits["seed"] ^ week_start)
    activity = traits["activity"]
    count = 1 + int(activity * 4)
    result = []
    for attempt in range(count):
        if instant and attempt == 0:
            result.append(week_start)
            continue
        day = rng.randrange(7)
        hour = (traits["utc_hour"] + rng.uniform(-2.0, 2.0)) % 24
        result.append(min(ends_at - 60, int(week_start + day * 86400 + hour * 3600)))
    return sorted(set(result))


def add_jobs(plan, profile, entries, group=None, history=False, instant=False):
    rng = random.Random(profile["traits"]["seed"] ^ plan["week_start"])
    for slot, entry in enumerate(entries):
        # Low activity drivers occasionally leave a weekly circuit unplayed.
        if not history and profile["traits"]["activity"] < 0.4 and rng.random() < 0.1:
            continue
        times = (
            [plan["server_now"]]
            if history
            else schedule(profile["traits"], plan["week_start"], plan["ends_at"], instant)
        )
        # Creating a plan late in the week spreads overdue attempts forward.
        overdue = 0
        for attempt, due in enumerate(times):
            if due < plan["server_now"]:
                due = plan["server_now"] + (0 if instant and attempt == 0 else overdue * 900)
                overdue += 1
            if due >= plan["ends_at"]:
                continue
            job_id = digest(
                {
                    "subject": profile["subject"],
                    "version": entry["version_id"],
                    "week": plan["week_start"],
                    "group": group,
                    "history": history,
                    "attempt": attempt,
                }
            )
            if any(job["id"] == job_id for job in plan["jobs"]):
                continue
            plan["jobs"].append(
                {
                    "id": job_id,
                    "subject": profile["subject"],
                    "slot": slot,
                    "version_id": entry["version_id"],
                    "content_hash": entry["content_hash"],
                    "attempt": attempt,
                    "due": due,
                    "group_id": group,
                    "status": "waiting",
                    "generation_failures": 0,
                }
            )


def prepare(api, arguments):
    if arguments.state.exists():
        raise ValueError("Plan already exists. Use tick/watch to resume it, or a new state path")
    count = arguments.count - 1 if arguments.command == "fill" else arguments.count
    fleet = api.call(
        "POST",
        "/dev/test-drivers/fleets",
        {
            "seed": arguments.seed,
            "count": count,
            "skill_min": 0.42 if arguments.command == "fill" else 0.0,
            "skill_max": 0.58 if arguments.command == "fill" else 1.0,
        },
        operator=True,
    )
    catalog = api.call("GET", "/dev/test-drivers/tracks?vehicle_id=" + arguments.vehicle, operator=True)
    if len(catalog["tracks"]) < 5:
        raise ValueError("Five eligible original tracks are needed")
    timestamp = catalog["server_now"]
    day = timestamp // 86400
    start = (day - (day + 3) % 7) * 86400
    plan = {
        "schema": SCHEMA,
        "api": api.url,
        "fleet": fleet["fleet"],
        "profiles": fleet["profiles"],
        "vehicle_id": arguments.vehicle,
        "mode": arguments.command,
        "week_start": start,
        "ends_at": start + 604800,
        "server_now": timestamp,
        "manifest": catalog["manifest"],
        "jobs": [],
        "joined": [],
        "pace_scales": {},
        "instant": arguments.instant,
    }
    if arguments.pace_reference:
        references = json.loads(arguments.pace_reference.read_text(encoding="utf-8"))
        if not isinstance(references, dict) or any(type(v) is not int or v <= 0 for v in references.values()):
            raise ValueError("Pace reference maps version_id to verified five-lap time_ticks")
        plan["pace_reference"] = references
    if arguments.command == "fill":
        target = arguments.target_subject
        group = api.call(
            "POST",
            "/rivalry/join",
            {"vehicle_id": arguments.vehicle, "test_population": True},
            target,
            digest({"fleet": fleet["fleet"], "join": target, "week": start}),
        )
        group = api.call(
            "POST",
            f"/dev/test-drivers/fleets/{fleet['fleet']}/fill",
            {"group_id": group["group_id"], "total_drivers": arguments.count},
            target,
            operator=True,
        )
        member_ids = {p["id"] for p in group["standings"]}
        plan["profiles"] = [p for p in plan["profiles"] if p["player_id"] in member_ids]
        plan["target_subject"], plan["group_id"] = target, group["group_id"]
        entries = [track["entry"] for track in group["tracks"]]
        # Existing verified human PBs are the default pace reference. Missing
        # history stays uncalibrated; the tool never invents a target time.
        references = plan.setdefault("pace_reference", {})
        for entry in entries:
            if entry["version_id"] in references:
                continue
            board = api.call(
                "GET",
                "/track-versions/" + entry["version_id"] + "/leaderboard?vehicle_id=" + arguments.vehicle,
            )
            if board["population"]:
                around = api.call("GET", "/boards/" + board["board_id"] + "/around-me", subject=target)
                if around.get("player"):
                    references[entry["version_id"]] = around["player"]["time_ticks"]
        for profile in plan["profiles"]:
            add_jobs(plan, profile, entries, group["group_id"], instant=arguments.instant)
        print(f"Test rivalry: {group['driver_count']} drivers including {target}")
    else:
        # Shared isolated history boards establish real percentile distributions.
        entries = sorted(catalog["tracks"], key=lambda e: e["version_id"])[:3]
        for profile in plan["profiles"]:
            add_jobs(plan, profile, entries, history=True)
        print(f"Test fleet: {count} profiles, {len(plan['jobs'])} verified history attempts planned")
    atomic_save(arguments.state, plan)
    return plan


def load_plan(path, api):
    plan = json.loads(path.read_text(encoding="utf-8"))
    if plan.get("schema") != SCHEMA or plan.get("api") != api.url:
        raise ValueError("Plan schema or service differs")
    return plan


def recording(api, plan, job, profile, settings, state_path):
    cache = state_path.parent / (state_path.stem + "-recordings")
    cache.mkdir(parents=True, exist_ok=True)
    path = cache / (job["id"] + ".json")
    if path.exists():
        result = json.loads(path.read_text(encoding="utf-8"))
    else:
        document = api.call("GET", "/track-versions/" + job["version_id"] + "/document")
        if digest(document) != job["content_hash"]:
            raise RuntimeError("Pinned track document hash changed")
        scale = plan["pace_scales"].get(job["version_id"], 1.0)
        reference = plan.get("pace_reference", {}).get(job["version_id"])
        if reference and job["version_id"] not in plan["pace_scales"]:
            # Calibrate a neutral driver by actually driving; never rewrite a time.
            neutral = {
                **profile["traits"],
                "skill": 0.5,
                "strengths": {},
                "consistency": 1.0,
                "aggression": 0.5,
            }
            low, high, closest = 0.6, 2.0, None
            for _ in range(6):
                scale = (low + high) / 2
                try:
                    sample = generate(settings, document, plan["vehicle_id"], neutral, 0, scale)
                except DriverDidNotFinish:
                    high = scale
                    continue
                error = abs(sample["time_ticks"] - reference)
                if closest is None or error < closest[0]:
                    closest = error, scale
                if sample["time_ticks"] > reference:
                    low = scale
                else:
                    high = scale
            if closest is None:
                raise DriverDidNotFinish("Neutral driver could not finish calibration")
            scale = closest[1]
            plan["pace_scales"][job["version_id"]] = scale
            relative_error = closest[0] / reference
            plan.setdefault("calibration", {})[job["version_id"]] = {
                "reference_ticks": reference,
                "relative_error": relative_error,
                "pace_scale": scale,
            }
            if relative_error > 0.05:
                print(
                    f"Circuit {job['slot'] + 1}: closest honest controller pace differs from the PB by {relative_error:.0%}"
                )
            atomic_save(state_path, plan)
        result = generate(settings, document, plan["vehicle_id"], profile["traits"], job["attempt"], scale)
        if build_contract(result["manifest"]) != build_contract(plan["manifest"]):
            raise RuntimeError("Local generator and service have different canonical builds")
        atomic_save(path, result)
    return result


def tick(api, plan, settings, path, maximum=4):
    current = api.call("GET", "/dev/test-drivers/tracks?vehicle_id=" + plan["vehicle_id"], operator=True)
    if build_contract(current["manifest"]) != build_contract(plan["manifest"]):
        raise RuntimeError("Service build changed. Keep this plan for inspection and create a new one")
    timestamp = current["server_now"]
    by_subject = {p["subject"]: p for p in plan["profiles"]}
    for job in plan["jobs"]:
        if job["status"] == "submitted":
            run = api.call("GET", "/runs/" + job["run_id"], subject=job["subject"])
            if run["status"] in ("verified", "rejected", "failed"):
                if run["status"] == "failed" and run.get("retryable") and job.get("retries", 0) < 3:
                    api.call(
                        "POST",
                        "/runs/" + job["run_id"] + "/retry",
                        {},
                        job["subject"],
                        job["id"] + "-retry-" + str(job.get("retries", 0)),
                    )
                    job["retries"] = job.get("retries", 0) + 1
                else:
                    job["status"], job["time_ticks"], job["failure_code"] = (
                        run["status"],
                        run["time_ticks"],
                        run["failure_code"],
                    )
                    print(
                        f"{job['subject']} · circuit {job['slot'] + 1} · {run['status']} · {run['time_ticks']} ticks"
                    )
                atomic_save(path, plan)
    # Join only once the shared history population has actually been verified.
    history = [job for job in plan["jobs"] if job["group_id"] is None]
    if (
        timestamp < plan["ends_at"]
        and plan["mode"] == "fleet"
        and history
        and all(j["status"] in ("verified", "rejected", "failed", "uncompleted", "expired") for j in history)
    ):
        for profile in plan["profiles"]:
            if profile["subject"] in plan["joined"]:
                continue
            group = api.call(
                "POST",
                "/rivalry/join",
                {"vehicle_id": plan["vehicle_id"], "test_population": True},
                profile["subject"],
                digest({"join": profile["subject"], "week": plan["week_start"]}),
            )
            add_jobs(
                plan,
                profile,
                [t["entry"] for t in group["tracks"]],
                group["group_id"],
                instant=plan["instant"],
            )
            plan["joined"].append(profile["subject"])
            atomic_save(path, plan)
            # Bound expensive scheduler passes, including sign-in traffic.
            maximum -= 1
            if maximum <= 0:
                break
    started = 0
    for job in sorted(plan["jobs"], key=lambda j: (j["due"], j["id"])):
        if started >= maximum:
            break
        if job["status"] != "waiting" or job["due"] > timestamp:
            continue
        if timestamp >= plan["ends_at"]:
            job["status"] = "expired"
            atomic_save(path, plan)
            continue
        profile = by_subject[job["subject"]]
        try:
            data = recording(api, plan, job, profile, settings, path)
        except DriverDidNotFinish as error:
            # A failed drive records an honest noncompletion, never a made-up PB.
            job["status"], job["failure_code"] = "uncompleted", str(error)
            atomic_save(path, plan)
            started += 1
            continue
        if "ticket" not in job:
            if job["group_id"]:
                ticket = api.call(
                    "POST",
                    "/rivalry/" + job["group_id"] + "/tickets",
                    {"slot": job["slot"]},
                    job["subject"],
                    job["id"] + "-ticket-" + str(job.get("ticket_generation", 0)),
                )
            else:
                ticket = api.call(
                    "POST",
                    "/run-tickets",
                    {
                        "version_id": job["version_id"],
                        "vehicle_id": plan["vehicle_id"],
                        "test_population": True,
                    },
                    job["subject"],
                    job["id"] + "-ticket-" + str(job.get("ticket_generation", 0)),
                )
            job["ticket"] = ticket
            atomic_save(path, plan)
        if job["ticket"]["expires_at"] <= timestamp:
            # The previous POST may have reached the server before a crash.
            # Retry its same content/key first to recover a committed run.
            try:
                run = api.call(
                    "POST",
                    "/runs",
                    {"ticket_id": job["ticket"]["ticket_id"], "replay": data["replay"]},
                    job["subject"],
                    job["id"] + "-upload-" + str(job.get("ticket_generation", 0)),
                )
            except RuntimeError as error:
                if "HTTP 410:" not in str(error):
                    raise
                del job["ticket"]
                job["ticket_generation"] = job.get("ticket_generation", 0) + 1
                atomic_save(path, plan)
                continue
        else:
            run = api.call(
                "POST",
                "/runs",
                {"ticket_id": job["ticket"]["ticket_id"], "replay": data["replay"]},
                job["subject"],
                job["id"] + "-upload-" + str(job.get("ticket_generation", 0)),
            )
        job["run_id"], job["status"] = run["run_id"], "submitted"
        job["generated_ticks"], job["mistakes"] = data["time_ticks"], data["mistakes"]
        atomic_save(path, plan)
        started += 1
    counts = {
        state: sum(j["status"] == state for j in plan["jobs"])
        for state in sorted({j["status"] for j in plan["jobs"]})
    }
    if (
        timestamp < plan["ends_at"]
        and plan["mode"] == "fleet"
        and history
        and all(j["status"] in ("verified", "rejected", "failed", "uncompleted", "expired") for j in history)
    ):
        counts["joining"] = len(plan["profiles"]) - len(plan["joined"])
    print("Plan:", counts)
    return counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("fill", "fleet", "tick", "watch"))
    parser.add_argument("--api", default=os.environ.get("BMT_API_URL", "http://127.0.0.1:18181"))
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=27)
    parser.add_argument("--count", type=int)
    parser.add_argument("--vehicle", default="compact")
    parser.add_argument("--target-subject", default="developer")
    parser.add_argument(
        "--instant",
        action="store_true",
        help="Make first weekly attempts due immediately; later attempts keep their schedule",
    )
    parser.add_argument("--pace-reference", type=Path, help="JSON mapping version_id to verified five-lap time_ticks")
    parser.add_argument("--max-jobs", type=int, default=4)
    parser.add_argument("--interval", type=int, default=15)
    parser.add_argument("--godot", default=os.environ.get("BMT_GODOT_BIN", ""))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2] / "game")
    arguments = parser.parse_args()
    if arguments.count is None:
        arguments.count = 14 if arguments.command == "fill" else 150
    if arguments.command == "fill" and not 2 <= arguments.count <= 20:
        parser.error("A rivalry needs 2–20 total drivers")
    if arguments.command == "fleet" and not 1 <= arguments.count <= 200:
        parser.error("A fleet needs 1–200 test drivers")
    if not 1 <= arguments.max_jobs <= 20 or not 10 <= arguments.interval <= 60:
        parser.error("Use 1–20 jobs per pass and a 10–60 second watch interval")
    settings = Settings(
        godot_bin=arguments.godot, game_project=str(arguments.project), verifier_timeout_seconds=90
    )
    if arguments.command in ("tick", "watch") and not settings.godot_bin:
        parser.error("Set BMT_GODOT_BIN to the exact executable in godot-version.txt")
    plan_lock = None
    try:
        api = API(arguments.api, os.environ.get("BMT_DEV_AUTH_KEY", ""))
        plan_lock = acquire_plan_lock(arguments.state)
        plan = (
            prepare(api, arguments)
            if arguments.command in ("fill", "fleet")
            else load_plan(arguments.state, api)
        )
        if arguments.command in ("fill", "fleet"):
            print(f"Saved {arguments.state}. Run tick or watch to drive the planned attempts")
            return
        while True:
            counts = tick(api, plan, settings, arguments.state, arguments.max_jobs)
            if arguments.command != "watch" or not (
                counts.get("waiting") or counts.get("submitted") or counts.get("joining")
            ):
                return
            time.sleep(arguments.interval)
    except KeyboardInterrupt:
        print("Scheduler stopped. Run watch with the same state path to resume")
    except (ValueError, RuntimeError, OSError, requests.RequestException) as error:
        parser.exit(1, f"Test population: {str(error)[:250]}\n")
    finally:
        if plan_lock is not None:
            plan_lock.close()


if __name__ == "__main__":
    main()
