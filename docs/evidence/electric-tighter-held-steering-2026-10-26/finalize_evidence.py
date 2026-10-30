"""Audit this task's evidence and create a source-scoped review checkpoint."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
PREFIX = "docs/evidence/electric-tighter-held-steering-2026-10-26"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(name: str) -> dict:
    return json.loads((OUT / name).read_text(encoding="utf-8"))


def log_result(name: str) -> dict:
    path = OUT / name
    raw = path.read_bytes()
    text = raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
    matches = re.findall(r"(?:checks|scripts), (\d+) failures", text)
    assert matches and matches[-1] == "0", name
    counts = re.findall(r"(\d+) (?:checks|scripts), \d+ failures", text)
    assert "SCRIPT ERROR:" not in text and "FAIL:" not in text, name
    return {"log": f"{PREFIX}/{name}", "checks": int(counts[-1]), "failures": 0}


def main() -> None:
    suite_logs = {
        "held_authority": "test_electric_held_authority-final.log",
        "corner_authority": "test_electric_corner_authority-final.log",
        "over_and_under": "test_electric_over_under-final.log",
        "normal_tracks": "test_electric_normal_tracks-final.log",
        **{name: f"test_{name}-final.log" for name in (
            "electric_consistent_handling", "electric_190", "electric_turn_radius",
            "electric_launch_drift", "electric_low_speed_steering", "electric_brake_release",
            "electric_car", "electric_one_pedal", "electric_power", "electric_power_balance",
            "electric_steering_response", "electric_turning",
        )},
        **{name: f"test_{name}-final.log" for name in (
            "electric_power_laps", "handling", "rewind", "script_parse",
        )},
        "native_compatibility": "native-compatibility-final.log",
        "native_desktop_mobile": "native-mobile-final.log",
    }
    results = {name: log_result(path) for name, path in suite_logs.items()}
    backend = (OUT / "backend-pytest.log").read_text(encoding="utf-16")
    assert "72 passed, 2 deselected, 6 warnings" in backend
    results["backend"] = {
        "passed": 72, "deselected": 2, "warnings": 6, "seconds": 137.33,
        "log": f"{PREFIX}/backend-pytest.log",
        "existing_exclusions": ["postgres", "retained_over_and_under_rejection"],
    }
    import_log = (OUT / "import.log").read_text(encoding="utf-16")
    assert "SCRIPT ERROR:" not in import_log and "ERROR:" not in import_log
    results["import"] = {"exit_code": 0, "log": f"{PREFIX}/import.log"}

    exact = {}
    for rel in ("game/vehicle/vehicle_simulation.gd", "game/vehicle/handling_config.gd",
                "game/input/route_driver.gd"):
        path = ROOT / rel
        assert path.read_bytes() == (OUT / "before" / rel.replace("/", "__")).read_bytes()
        exact[rel] = digest(path)

    config_path = ROOT / "game/resources/cars/electric.tres"
    previous_config = OUT / "before/game__resources__cars__electric.tres"
    def config_fields(path: Path) -> dict:
        return dict(re.findall(r"^([a-z_]+) = (.+)$", path.read_text(encoding="utf-8"), re.M))
    old_fields, new_fields = config_fields(previous_config), config_fields(config_path)
    changed_fields = {key: {"before": old_fields.get(key), "after": value}
                      for key, value in new_fields.items() if old_fields.get(key) != value}
    assert set(changed_fields) == {"version", "countersteering_rate", "steering_angle",
                                  "high_speed_steering_reduction", "low_speed_turn_radius",
                                  "low_speed_turn_acceleration", "launch_lateral_response_scale"}

    old_fixture = json.loads((OUT / "before/backend__tests__fixtures__verified_oval.json").read_text(encoding="utf-8"))
    new_fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text(encoding="utf-8"))
    old_fixture["expected_manifest"]["vehicles"]["electric"] = new_fixture["expected_manifest"]["vehicles"]["electric"]
    assert old_fixture == new_fixture
    canonical = read_json("canonical-verification.json")
    assert canonical["input_count"] == canonical["time_ticks"] == 36278
    assert canonical["electric"]["config_hash"] == "ec52cbce257e3552996e8515894b985c976cd4e8586c1ef11810607779b661c3"
    assert (OUT / "canonical-race.json").read_bytes() == (OUT / "over-under-race.json").read_bytes()
    profile = read_json("continuous-handling.json")
    circles = {key: {"before_metres": value["before"]["radius"],
                     "after_metres": value["after"]["radius"]}
               for key, value in profile["metrics"]["circles"].items()}

    changes = {}
    for before in sorted((OUT / "before").iterdir()):
        if before.name == "AGENTS.md":
            continue
        rel = before.name.replace("__", "/")
        after = ROOT / rel
        if after.read_bytes() != before.read_bytes():
            changes[rel] = (before.read_text(encoding="utf-8"), after.read_text(encoding="utf-8"))
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    start = "<!-- ELECTRIC-TIGHTER-HELD-STEERING-20261026 -->"
    end = "<!-- /ELECTRIC-TIGHTER-HELD-STEERING-20261026 -->"
    entry = agents[agents.index(start):agents.index(end) + len(end)] + "\n\n"
    # Rebase only our entry onto current concurrent documentation. Preserve
    # unrelated new entries and edits on both sides of the review patch.
    base = agents.replace(entry, "", 1)
    (OUT / "AGENTS-scoped-checkpoint-base.md").write_text(base, encoding="utf-8")
    changes["AGENTS.md"] = (base, agents)
    for rel in ("game/tests/test_electric_held_authority.gd", "game/tests/test_electric_held_authority.gd.uid",
                "docs/ELECTRIC_TIGHTER_HELD_STEERING_2026_10_26.md"):
        changes[rel] = ("", (ROOT / rel).read_text(encoding="utf-8"))

    patch = []
    for rel, (before, after) in sorted(changes.items()):
        patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                         fromfile=f"a/{rel}" if before else "/dev/null", tofile=f"b/{rel}",
                                         n=2 if rel == "AGENTS.md" else 3))
    (OUT / "checkpoint.patch").write_text("".join(patch), encoding="utf-8")
    source_hashes = {rel: digest(ROOT / rel) for rel in sorted(changes)}
    evidence_hashes = {path.relative_to(ROOT).as_posix(): digest(path)
                       for path in sorted(OUT.rglob("*")) if path.is_file()
                       and path.name not in ("report.json", "checkpoint.patch")}
    report = {
        "requirements": ["EHT01", "EHT02", "EHT03", "R01", "Q01"],
        "owner_request": "still too stiff to steer; responds promptly, curve too wide",
        "date": "2026-10-26", "handling_version": "electric-15", "physics_version": "arcade-planar-0.73",
        "changed_fields": changed_fields, "source_hashes": source_hashes,
        "exact_task_start_sources": exact, "results": results, "held_radius_metres": circles,
        "corner_metrics": read_json("keyboard-corners.json")["metrics"],
        "normal_tracks": read_json("normal-tracks.json")["metrics"],
        "canonical_verification": canonical,
        "retained_failures": {'initial_excess_launch_slip': {'checks': 53, 'failures': 1, 'log': 'held-authority-initial.log', 'json': 'initial-excess-launch-slip.json'}, 'initial_corner_release_alignment': {'checks': 32, 'failures': 4, 'log': 'test_electric_corner_authority-initial.log'}, 'superseded_contracts': {'electric_consistent_handling': [530, 4], 'electric_launch_drift': [111, 1], 'electric_low_speed_steering': [87, 32], 'electric_steering_response': [86, 14], 'electric_turn_radius': [64, 13], 'electric_turning': [61, 9]}, 'native_old_heading_ceiling': {'checks': 70, 'failures': 1, 'log': 'native-compatibility-initial.log'}, 'first_pass_json_directory': 'first-pass'},
        "evidence_hashes": evidence_hashes,
        "checkpoint": {"path": f"{PREFIX}/checkpoint.patch", "sha256": digest(OUT / "checkpoint.patch"),
                       "source_scoped": True, "staged": False, "committed": False,
                       "reverse_check": "pending"},
        "limits": ["Synthetic input and artificial diagnostic drivers; owner keyboard/controller feel remains unaccepted",
                   "Direct corners use binary steering and analog speed feedback, not physical full-throttle keyboard driving",
                   "Five Storm laps are one-lap diagnostics; production race rules remain five laps",
                   "Desktop renderers only; physical-device attachment check/test not performed",
                   "Reload/rebuild and matching verifier configuration rollout remain",
                   "No APK, purchase, live mutation, deployment, merge or owner-process restart"],
    }
    command = ["git", "-c", "core.autocrlf=false", "apply", "--reverse", "--check", "--ignore-space-change", str(OUT / "checkpoint.patch")]
    checked = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    assert checked.returncode == 0, checked.stderr
    report["checkpoint"]["reverse_check"] = {"exit_code": checked.returncode, "command": command}
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Audited {len(results)} results and {len(changes)} scoped source files.")


if __name__ == "__main__":
    main()
