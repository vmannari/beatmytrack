"""Explicit local controller passes; uploads use ordinary tickets and verification."""
import argparse
import json
import os
import time
import uuid
from pathlib import Path

from .config import Settings
from .contracts import build_contract
from .test_driver_generator import DriverDidNotFinish, GenerationTimedOut, controller_engine, generate
from .test_population_tool import API, acquire_plan_lock, atomic_save, load_plan, recording, tick
from .track_models import digest

SCHEMA = "local-artificial-races-v1"


def run_rivalry(api, settings, state_path, group_id, maximum=1):
    """Use existing artificial memberships and ordinary rivalry ticket proofs."""
    lock = acquire_plan_lock(state_path)
    try:
        if state_path.exists():
            plan = load_plan(state_path, api)
            if plan.get("fleet") != "auto-"+group_id:
                raise ValueError("Local plan belongs to another artificial rivalry")
        else:
            plan = api.call("GET", "/dev/test-drivers/local-rivalries/"+group_id+"/plan", operator=True)
            plan["api"] = api.url
            atomic_save(state_path, plan)
        with controller_engine(settings) as verifier:
            if build_contract(verifier.manifest()) != build_contract(plan["manifest"]):
                raise RuntimeError("Local engine build differs from the service")
        counts = {}
        for _ in range(maximum):
            deadline = time.monotonic()+420
            def bounded_generator(*args, _deadline=deadline, **kwargs):
                return generate(*args, **kwargs, deadline=_deadline)
            counts = tick(api, plan, settings, state_path, maximum=1, generator=bounded_generator)
            if not counts.get("waiting"):
                break
        return {"results": counts, "execution": "local_on_demand", "group_id": group_id}
    finally:
        lock.close()


def run_pass(api, settings, state_path, batch_id, maximum=1):
    state_path = Path(state_path)
    lock = acquire_plan_lock(state_path)
    try:
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {
            "schema": SCHEMA, "api": api.url, "batch_id": batch_id, "runner_id": str(uuid.uuid4()), "receipts": {}}
        if state.get("schema") != SCHEMA or state.get("api") != api.url or state.get("batch_id") != batch_id:
            raise ValueError("Local runner state belongs to another service or batch")
        atomic_save(state_path, state)
        results = []
        checked = False
        for _ in range(maximum):
            response = api.call("POST", "/dev/test-drivers/batches/"+batch_id+"/claim",
                {"runner_id": state["runner_id"]}, operator=True)
            work = response.get("work")
            if work is None:
                return {"attempted": len(results), "results": results, "batch": response.get("batch")}
            if not checked:
                with controller_engine(settings) as verifier:
                    if build_contract(verifier.manifest()) != build_contract(work["manifest"]):
                        raise RuntimeError("Local engine build differs from the service; use its pinned worker image")
                checked = True
            original = work["job"]
            job = {**original, "id": digest({"job": original["id"], "attempt": original["attempt"]})}
            # Retain only an unresolved receipt. Historical server results are
            # authoritative; this is a bounded crash-recovery journal.
            state["receipts"] = {job["id"]: state["receipts"].get(job["id"], {})}
            atomic_save(state_path, state)
            prefix = "/dev/test-drivers/batches/"+batch_id+"/jobs/"+original["id"]+"/complete"
            outcome = {"lease_token": original["lease_token"]}
            try:
                receipt = state["receipts"].get(job["id"], {})
                if receipt.get("ticket") and not receipt.get("run_id"):
                    accepted = api.call("GET", "/run-tickets/"+receipt["ticket"]["ticket_id"]+"/submission", subject=job["subject"])
                    if accepted.get("run"):
                        receipt["run_id"] = accepted["run"]["run_id"]
                    elif receipt["ticket"]["expires_at"] <= time.time():
                        # A new ticket is permitted only after the old ticket
                        # confirms that it never accepted a submission.
                        receipt.pop("ticket")
                        receipt["ticket_generation"] = receipt.get("ticket_generation", 0)+1
                    state["receipts"][job["id"]] = receipt; atomic_save(state_path, state)
                if not receipt.get("run_id"):
                    suffix = "-"+str(receipt["ticket_generation"]) if receipt.get("ticket_generation") else ""
                    recovered = api.call("GET", "/dev/test-drivers/uploads/"+job["id"]+"-upload"+suffix,
                        subject=job["subject"], operator=True)
                    if recovered.get("run"):
                        receipt = {"run_id": recovered["run"]["run_id"]}
                    elif recovered.get("retired"):
                        raise RuntimeError("Original upload history retired; keep this local journal for review")
                    else:
                        plan = {"vehicle_id": work["vehicle_id"], "manifest": work["manifest"], "pace_scales": {}}
                        deadline = time.monotonic() + 420
                        def bounded_generator(*args, _deadline=deadline, **kwargs):
                            return generate(*args, **kwargs, deadline=_deadline)
                        result = recording(api, plan, job, {"traits": work["traits"]}, settings, state_path,
                            generator=bounded_generator)
                        if "ticket" not in receipt:
                            receipt["ticket"] = api.call("POST", "/run-tickets", {"version_id": job["version_id"],
                                "vehicle_id": work["vehicle_id"], "test_population": True}, job["subject"], job["id"]+"-ticket"+suffix)
                            state["receipts"][job["id"]] = receipt; atomic_save(state_path, state)
                        uploaded = api.call("POST", "/runs", {"ticket_id": receipt["ticket"]["ticket_id"],
                            "replay": result["replay"]}, job["subject"], job["id"]+"-upload"+suffix)
                        receipt["run_id"] = uploaded["run_id"]
                    state["receipts"][job["id"]] = receipt; atomic_save(state_path, state)
                outcome["run_id"] = receipt["run_id"]
            except GenerationTimedOut:
                outcome["failure"] = "timeout"
            except DriverDidNotFinish:
                outcome["failure"] = "not_finished"
            results.append(api.call("POST", prefix, outcome, operator=True)["status"])
            state["receipts"].clear()
            atomic_save(state_path, state)
            # Only this acknowledged, reproducible recording is removed.
            saved = state_path.parent / (state_path.stem + "-recordings") / (job["id"] + ".json")
            saved.unlink(missing_ok=True)
        return {"attempted": len(results), "results": results,
            "batch": api.call("GET", "/dev/test-drivers/batches/"+batch_id, operator=True)}
    finally:
        lock.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", required=True)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--batch", type=uuid.UUID)
    target.add_argument("--rivalry", type=uuid.UUID)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--cache-dir", type=Path, help="Share bounded prepared trajectories across batches")
    parser.add_argument("--max-jobs", type=int, default=1)
    parser.add_argument("--godot", default=os.environ.get("BMT_GODOT_BIN", ""))
    parser.add_argument("--project", default=os.environ.get("BMT_GAME_PROJECT", ""))
    args = parser.parse_args()
    if not 1 <= args.max_jobs <= 20 or not args.godot or not args.project:
        parser.error("Use 1–20 jobs and an explicit pinned Godot executable/project")
    settings = Settings(environment="test", godot_bin=args.godot, game_project=args.project,
        object_dir=str((args.cache_dir or args.state.parent) / "objects"))
    api = API(args.api, os.environ.get("BMT_DEV_AUTH_KEY", ""))
    try:
        if args.rivalry:
            print(json.dumps(run_rivalry(api, settings, args.state, str(args.rivalry), args.max_jobs)))
            return
        result = run_pass(api, settings, args.state, str(args.batch), args.max_jobs)
        batch = result.get("batch") or {}
        print(json.dumps({"attempted": result["attempted"], "results": result["results"],
            "jobs": batch.get("jobs"), "complete": batch.get("complete"), "execution": "local_on_demand"}))
    finally:
        api.http.close()


if __name__ == "__main__":
    main()
