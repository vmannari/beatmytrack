"""Audit this task's evidence and create a source-scoped review checkpoint."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
PREFIX = "docs/evidence/electric-driving-character-2026-10-26"


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
        "character": "test_electric_character-final.log",
        "powered_drift": "test_electric_powered_drift-final.log",
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
        "passed": 72, "deselected": 2, "warnings": 6, "seconds": 131.97,
        "log": f"{PREFIX}/backend-pytest.log",
        "existing_exclusions": ["postgres", "retained_over_and_under_rejection"],
    }
    import_log = (OUT / "import.log").read_text(encoding="utf-16")
    assert "SCRIPT ERROR:" not in import_log and "ERROR:" not in import_log
    results["import"] = {"exit_code": 0, "log": f"{PREFIX}/import.log"}

    exact = {}
    for rel in ("game/input/route_driver.gd", "game/input/driver_input.gd", "game/vehicle/vehicle_simulation.gd", "game/vehicle/handling_config.gd", "game/resources/original_slide.tres", "game/resources/compact_fun.tres", "game/ui/handling_selection.gd", "game/vehicle/vehicle_catalog.gd"):
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
    assert set(changed_fields) == {"version", "regeneration", "steering_rate", "rotational_inertia", "lateral_response", "launch_lateral_response_scale", "power_lateral_response_scale"}

    old_fixture = json.loads((OUT / "before/backend__tests__fixtures__verified_oval.json").read_text(encoding="utf-8"))
    new_fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text(encoding="utf-8"))
    old_fixture["expected_manifest"]["vehicles"]["electric"] = new_fixture["expected_manifest"]["vehicles"]["electric"]
    old_fixture["expected_manifest"]["physics_version"] = "arcade-planar-0.74"
    assert old_fixture == new_fixture
    canonical = read_json("canonical-verification.json")
    assert canonical["input_count"] == canonical["time_ticks"] == 34582
    assert canonical["electric"]["config_hash"] == "4ce920bc320196a5556c6e11407b299aac6c2078fecd8ac221e5a4a612750359"
    assert (OUT / "canonical-race.json").read_bytes() == (OUT / "over-under-race.json").read_bytes()
    profile = read_json("continuous-handling.json")
    previous_profile = read_json("task-start-continuous-handling.json")
    radius_delta=max(abs(value["after"]["radius"]/previous_profile["metrics"]["circles"][key]["after"]["radius"]-1.0) for key,value in profile["metrics"]["circles"].items())
    assert radius_delta<0.01
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
    start = "<!-- ELECTRIC-DRIVING-CHARACTER-20261026 -->"
    end = "<!-- /ELECTRIC-DRIVING-CHARACTER-20261026 -->"
    entry = agents[agents.index(start):agents.index(end) + len(end)] + "\n\n"
    # Rebase only our entry onto current concurrent documentation. Preserve
    # unrelated new entries and edits on both sides of the review patch.
    base = agents.replace(entry, "", 1)
    (OUT / "AGENTS-scoped-checkpoint-base.md").write_text(base, encoding="utf-8")
    changes["AGENTS.md"] = (base, agents)
    for rel in ("game/tests/test_electric_character.gd", "game/tests/test_electric_character.gd.uid", "game/tests/probe_electric_character.gd", "game/tests/probe_electric_character.gd.uid",
                "docs/ELECTRIC_DRIVING_CHARACTER_2026_10_26.md"):
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
    prior_root = ROOT / "docs/evidence/electric-powered-drift-2026-10-26"
    prior_report = json.loads((prior_root / "report.json").read_text(encoding="utf-8"))
    assert all(digest(ROOT / rel)==value for rel,value in prior_report["evidence_hashes"].items())
    restoration = read_json("evidence-restoration.json")
    assert restoration["all_previous_evidence_hashes_exact"]
    report = {
        "requirements": ["EDC01", "EDC02", "EDC03", "EDC04", "R01", "Q01"],
        "owner_request": "still does not feel fun; Compact is excellent but electric cannot be a copy; planted and punchy with controllable power slides",
        "date": "2026-10-26", "handling_version": "electric-17", "physics_version": "arcade-planar-0.74",
        "changed_fields": changed_fields, "source_hashes": source_hashes,
        "exact_task_start_sources": exact, "results": results, "held_radius_metres": circles,
        "corner_metrics": read_json("keyboard-corners.json")["metrics"],
        "normal_tracks": read_json("normal-tracks.json")["metrics"],
        "canonical_verification": canonical,
        "powered_drift": read_json("powered-drift.json")["metrics"],
        "ordinary_circle_max_change_percent": radius_delta*100.0,
        "character": read_json("character.json")["metrics"],
        "direction": "Planted and punchy, with controllable power slides",
        "owner_changed_behavior_contracts": ["12 rather than 26 m/s2 release; explicit new stopping windows", "connected weighted input/body/tyre response", "finite-response synthetic corner release rather than fixed 87 degrees"],
        "retained_protections": ["lane and 7-degree alignment bounds", "8-degree slip ceiling", "95-percent traction floor", "exact zero, direction and replay fences", "other-car identities and arithmetic"],
        "native_shutdown_warnings": "Two ObjectDB instances in each renderer; cause not attributed",
        "retained_failures": {'original_contracts': {'test_electric_corner_authority': {'checks': 32, 'failures': 8, 'log': 'test_electric_corner_authority-original.log'}, 'test_electric_launch_drift': {'checks': 111, 'failures': 4, 'log': 'test_electric_launch_drift-original.log'}, 'test_electric_powered_drift': {'checks': 275, 'failures': 48, 'log': 'test_electric_powered_drift-original.log'}, 'test_electric_190': {'checks': 57, 'failures': 5, 'log': 'test_electric_190-original.log'}, 'test_electric_brake_release': {'checks': 38, 'failures': 15, 'log': 'test_electric_brake_release-original.log'}, 'test_electric_one_pedal': {'checks': 63, 'failures': 2, 'log': 'test_electric_one_pedal-original.log'}, 'test_electric_consistent_handling': {'checks': 530, 'failures': 13, 'log': 'test_electric_consistent_handling-original.log'}, 'test_electric_car': {'checks': 60, 'failures': 1, 'log': 'test_electric_car-original.log'}, 'test_electric_power': {'checks': 19, 'failures': 3, 'log': 'test_electric_power-original.log'}, 'test_electric_power_balance': {'checks': 18, 'failures': 5, 'log': 'test_electric_power_balance-original.log'}, 'test_electric_steering_response': {'checks': 86, 'failures': 13, 'log': 'test_electric_steering_response-original.log'}}, 'parameter_matched_braking_initial': {'checks': 87, 'failures': 1, 'log': 'old-braking-identity.log'}, 'candidate_initial_comparison': 'initial-candidate-comparison.json', 'evidence_output_correction': 'evidence-restoration.json'},
        "previous_evidence_restoration": restoration,
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
