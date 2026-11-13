"""Reconcile accepted final measurements without treating cache warming as a gain."""
import hashlib
import json
import os
import statistics
import subprocess
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]


def read(name):
    return json.loads((OUT / name).read_text(encoding="utf-8"))


def log(name):
    data = (OUT / name).read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


def accepted(name):
    value = read(name + "/run.json")
    assert value["exit_code"] == 0 and not value["timeout"], name
    assert not value["source_changes"] and not value["script_error"], name
    return value


def comparison(before, after):
    return {"before_ms": before, "after_ms": after,
                "reduction_percent": (before - after) * 100 / before}


names = ["final-menus-control", "final-menus-candidate",
         "final-menus-warm-control", "final-menus-warm-candidate",
         "final-podium-hit-a", "final-podium-control", "final-podium-hit-b",
         "startup-control-e", "startup-final-e", "startup-control-f", "startup-final-f",
         "startup-owner-accepted-native", "final-audio-load", "final-startup-music",
         "accepted-menus-control", "accepted-menus-current", "accepted-menus-warm-control"]
receipts = {name: accepted(name) for name in names}
menus = []
before = read("final-menus-warm-control/result.json")["menus"]
after = read("final-menus-warm-candidate/result.json")["menus"]
for old, new in zip(before, after):
    assert (old["page"], old["cycle"]) == (new["page"], new["cycle"])
    field = "settled_ms" if old["page"] == "rivalry" else "ready_ms"
    menus.append(dict(page=old["page"], cycle=old["cycle"], metric=field,
                      **comparison(old[field], new[field])))

podium_rows = {}
for name in ["final-podium-hit-a", "final-podium-control", "final-podium-hit-b"]:
    podium_rows[name] = read(name + "/result.json")["menus"][0]
podium = comparison(podium_rows["final-podium-control"]["settled_ms"],
                    statistics.mean(podium_rows[n]["settled_ms"]
                                    for n in ["final-podium-hit-a", "final-podium-hit-b"]))
podium["rows"] = podium_rows

startup_rows = {}
for name in ["startup-control-e", "startup-final-e", "startup-control-f", "startup-final-f"]:
    line = next(line for line in receipts[name]["results"] if line.startswith("SHELL_PROFILE "))
    startup_rows[name] = json.loads(line.removeprefix("SHELL_PROFILE "))
startup = comparison(statistics.mean(startup_rows[n]["engine_to_menu_ms"]
                                    for n in ["startup-control-e", "startup-control-f"]),
                     statistics.mean(startup_rows[n]["engine_to_menu_ms"]
                                     for n in ["startup-final-e", "startup-final-f"]))
startup["rows"] = startup_rows
accepted_menus = []
for old, new in zip(read("accepted-menus-warm-control/result.json")["menus"],
                    read("accepted-menus-current/result.json")["menus"]):
    assert (old["page"], old["cycle"]) == (new["page"], new["cycle"])
    accepted_menus.append(dict(page=old["page"], cycle=old["cycle"],
                               **comparison(old["ready_ms"], new["ready_ms"])))
backend_log = log("backend/tests-combined-final.log")
backend = next(line for line in backend_log.splitlines() if "24 passed, 1 skipped" in line)
assert "All checks passed!" in log("backend/ruff-combined-final.log")
assert "1925 checks, 0 failures" in log("prepared-final/prepared-preflight.log")
assert "5 exact native images, 156 current source hashes" in log("prepared-final/pictures-preflight.log")
assert "1925 checks, 0 failures" in log("prepared-accepted/prepared-preflight.log")
assert "5 exact native images, 156 current source hashes" in log("prepared-accepted/pictures-preflight.log")
assert "FEATURE_PARSE_FAILURES 0" in log("standard-feature-parse-checked.log")
assert "FEATURE_PARSE_FAILURES 0" in log("standard-accepted-feature-parse.log")
env = {**os.environ, "GIT_OPTIONAL_LOCKS": "0"}
head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, env=env, text=True).strip()
staged = subprocess.check_output(["git", "diff", "--cached", "--name-only"], cwd=ROOT, env=env, text=True).strip()
assert head == read("task-start.json")["head"] and not staged
source_paths = ["game/core/app.gd", "game/soundtrack/audio_world.gd", "game/editor/editor_memory.gd",
                "game/track/prepared_world_cache.gd", "game/ui/player_profile.gd"]
frozen = Path(read("accepted-project.json")["project"]).parent
for path in source_paths:
    assert (ROOT / path).read_bytes() == (frozen / path).read_bytes(), path
for path in ["game/ui/rivalry_victory_car.gd", "game/ui/weekly_rivalry_page.gd"]:
    assert (ROOT / path).read_bytes() == (OUT / "graphics/before" / path).read_bytes(), path
for path in ["game/ui/rivalry_cached_podium.gd", "game/ui/rivalry_podium_pictures.gd"]:
    assert not (ROOT / path).exists(), path
report = {"requirements": ["LHF01", "LHF02", "LHF03", "LHF04", "LHF05", "LHFQ01"],
              "target_half_all_loading_times_met": False, "device_test_performed": False,
              "menus": accepted_menus, "rejected_candidate_menus": menus,
              "rejected_podium_experiment": podium, "startup": startup, "backend": backend,
              "validated_runs_including_rejected_experiments": receipts,
              "shipping_podium_cache_enabled": False,
              "source_sha256": {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
                             for path in source_paths},
              "head": head, "staged_paths": staged,
              "index_before_sha256": read("task-start.json")["index_sha256"],
              "index_after_sha256": hashlib.sha256((ROOT / ".git/index").read_bytes()).hexdigest(),
              "limitations": ["Desktop RTX 3090 Compatibility; not Android measurements.",
                           "Warm process-independent caches; no reset of system driver caches.",
                           "First final control and candidate have unequal first-use cache state and are excluded from speedup attribution.",
                           "Two startup samples per arm overlap; no startup speedup established.",
                           "Final native correctness after the timing matrix may overlap Android compilation; timing excluded.",
                           "Index metadata changed during task inspection, while HEAD and staged content remained unchanged."]}
(OUT / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"menus": accepted_menus, "rejected_podium_experiment": {k: v for k, v in podium.items() if k != "rows"},
                  "startup": {k: v for k, v in startup.items() if k != "rows"},
                  "runs": len(receipts), "backend": backend}, indent=2))
