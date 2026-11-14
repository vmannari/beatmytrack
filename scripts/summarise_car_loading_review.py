"""Summarise read-only observations; no game assets or caches are written."""
from collections import defaultdict
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-optimisation-review-round2-2026-11-13"
CASES = {
    "compact-trace-gl_compatibility": "load-compact-trace-compat",
    "kart-gl_compatibility": "load-kart-compat",
    "forklift-gl_compatibility": "load-forklift-compat",
    "electric-gl_compatibility": "load-electric-compat",
    "hovercraft-gl_compatibility": "load-hovercraft-compat",
    "compact-fitted-gl_compatibility": "load-compact-fitted-compat",
    "compact-star-trace-mobile": "load-compact-star-mobile",
    "kart-mobile": "load-kart-mobile",
}


def read(name):
    return json.loads((OUT / name).read_text(encoding="utf-8"))


def main():
    cases = []
    checks = 0
    for name, label in CASES.items():
        data = read("loading-" + name + ".json")
        receipt = read(label + "-receipt.json")
        assert receipt["exit_code"] == 0 and not receipt["errors"]
        assert not receipt["changed_inputs"] and not data["failures"]
        assert len(data["samples"]) == 2
        assert all(s["base_hits"] == 1 and s["tick_at_reveal"] == 0
                   and s["countdown_at_reveal"] == 360 for s in data["samples"])
        audit = data["base_audit_after_timing"]
        assert audit["key_matches"] and audit["runtime_source_matches"] and audit["holder_valid"]
        checks += data["checks"]
        traces = []
        for sample in data["samples"]:
            buckets = defaultdict(lambda: {"draws": 0, "elapsed_us": 0, "program_groups": 0})
            car = sample.get("car_path", "/root/CircuitApp/Game/World/@Node3D@300"
                             if sample["cycle"] == 0 else "/root/CircuitApp/Game/World/@Node3D@931")
            for row in sample.get("draw_trace", []):
                paths = [p for group in row["groups"] for p in group]
                kinds = {"car" if p == car or p.startswith(car + "/")
                         else "world" if "/Game/" in p else "background" for p in paths}
                bucket = buckets["+".join(sorted(kinds))]
                bucket["draws"] += 1
                bucket["elapsed_us"] += row["elapsed_us"]
                bucket["program_groups"] += len(row["groups"])
            traces.append(dict(buckets))
        cases.append({
            "case": name, "source": "loading-" + name + ".json", "receipt": label + "-receipt.json",
            "startup_ms": data["startup_ms"], "app_scene_load_ms": data["app_scene_load_ms"],
            "first_race_ms": data["samples"][0]["race_wall_ms"],
            "repeat_race_ms": data["samples"][1]["race_wall_ms"],
            "first_car_ms": data["samples"][0]["game_costs"]["car_us"] / 1000,
            "repeat_car_ms": data["samples"][1]["game_costs"]["car_us"] / 1000,
            "retry_ms": [s["retry_ms"] for s in data["samples"]],
            "driver_cached_at_startup": data.get("driver_cached_at_startup"),
            "driver_cached_after_first_race": data["samples"][0].get("driver_cached"),
            "draw_intervals": traces,
        })

    inventory = read("headless/inventory.json")
    candidates = []
    for row in inventory["rows"]:
        before = row["baseline"]["buffer_bytes"]
        after = next(c["inventory"]["buffer_bytes"] for c in row["candidates"]
                     if c["mode"] == "share_exact_meshes")
        candidates.append({"vehicle": row["vehicle"], "before_bytes": before,
                           "shared_bytes": after, "saving_bytes": before - after,
                           "driver_split": row.get("driver_split")})
    result = {
        "scope": ["compact", "kart", "forklift", "electric", "hovercraft"],
        "production_changes_authored": False,
        "engine": "4.7.2.stable.official.ed1daf0bf", "adapter": "desktop RTX 3090",
        "cases": cases, "actual_app_checks": checks, "actual_app_failures": 0,
        "race_entries": len(cases) * 2, "retry_entries": len(cases) * 2,
        "headless_checks": inventory["checks"], "headless_failures": inventory["failures"],
        "raw_buffer_candidates": candidates,
        "caveats": [
            "Fresh processes with existing OS/import/driver shader caches; no controlled cold-cache comparison.",
            "Actual App car timing omits script-graph loads and later GPU/finish preparation.",
            "Draw intervals include frame scheduling and all visible work, not isolated GPU shader timings.",
            "Eight clean commands pin vehicle sources/assets/configurations and Git index, not all App source files.",
            "Headless candidate inventory used procedural fallbacks during concurrent cache regeneration.",
            "Sharing and driver split are raw-buffer prototypes, not published or visually qualified.",
            "No Android device timing, APK, deployment or production cache publication.",
        ],
        "excluded_attempts": {
            "load-compact": "Initial offline fixture lacked a local version pin; no race installed. Deferred teardown error retained.",
            "load-compact-compat": "23s observation retained only as diagnostic: concurrent vehicle-cache writes and one resource-in-use teardown diagnostic.",
        },
    }
    (OUT / "summary.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"app_checks": checks, "race_entries": len(cases) * 2,
                      "sharing_saving_bytes": sum(c["saving_bytes"] for c in candidates)}))


if __name__ == "__main__":
    main()
