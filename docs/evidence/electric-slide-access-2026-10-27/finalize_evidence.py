"""Audit the electric slide-access task and make a source-only review patch."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
PREFIX = OUT.relative_to(ROOT).as_posix()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_log(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


def read_json(name):
    return json.loads((OUT / name).read_text(encoding="utf-8"))


def main():
    initial = read_json("task-start.json")
    assert all(Path(p).is_file() and sha(Path(p)) == h for p, h in initial["prior_evidence"].items())
    results = {}
    suites = ["electric_slide_access", "electric_powered_drift", "electric_launch_drift",
              "electric_brake_release", "electric_190", "electric_character", "electric_held_authority",
              "electric_power", "electric_power_balance", "electric_car", "electric_one_pedal",
              "electric_low_speed_steering", "electric_steering_response", "electric_turning",
              "electric_turn_radius", "electric_corner_authority", "electric_consistent_handling",
              "electric_normal_tracks", "electric_over_under", "electric_power_laps",
              "handling", "rewind", "script_parse"]
    for name, log in [(s, "test_" + s + "-final.log") for s in suites] + [
            ("native_compatibility", "native-compatibility-final.log"),
            ("native_desktop_mobile", "native-mobile-final.log")]:
        content = read_log(OUT / log)
        matches = re.findall(r"(\d+) (?:checks|scripts), (\d+) failures", content)
        assert matches and matches[-1][1] == "0", log
        assert "FAIL:" not in content and "SCRIPT ERROR:" not in content, log
        results[name] = {"checks": int(matches[-1][0]), "failures": 0, "log": f"{PREFIX}/{log}"}
    backend = read_log(OUT / "backend-pytest-final.log")
    assert "72 passed, 2 deselected, 6 warnings" in backend
    results["backend"] = {"passed": 72, "deselected": 2, "warnings": 6,
                          "seconds": 128.24, "log": f"{PREFIX}/backend-pytest-final.log",
                          "existing_exclusions": ["postgres", "retained_over_and_under_rejection"]}
    import_log = read_log(OUT / "import.log")
    assert "ERROR:" not in import_log and "SCRIPT ERROR:" not in import_log
    results["import"] = {"exit_code": 0, "log": f"{PREFIX}/import.log"}

    def fields(path):
        return dict(re.findall(r"^([a-z_]+) = (.+)$", path.read_text(encoding="utf-8"), re.M))
    before = fields(OUT / "before/game__resources__cars__electric.tres")
    after = fields(ROOT / "game/resources/cars/electric.tres")
    delta = {k: {"before": before.get(k), "after": v} for k, v in after.items() if before.get(k) != v}
    assert set(delta) == {"version", "regeneration", "launch_lateral_response_scale",
                          "power_lateral_response_scale", "power_slide_full_pedal",
                          "power_slide_high_speed_scale", "slide_drive_loss"}
    exact = {}
    for rel in ["game/input/driver_input.gd", "game/vehicle/vehicle_catalog.gd",
                "game/resources/original_slide.tres", "game/resources/compact_fun.tres"]:
        assert sha(ROOT / rel) == initial["sources"][rel]
        exact[rel] = sha(ROOT / rel)
    historical = json.loads((ROOT / "docs/evidence/electric-driving-character-2026-10-26/report.json").read_text())
    for rel in ["game/input/route_driver.gd", "game/ui/handling_selection.gd"]:
        assert sha(ROOT / rel) == historical["exact_task_start_sources"][rel]
        exact[rel] = sha(ROOT / rel)
    old_fixture = read_json("before/backend__tests__fixtures__verified_oval.json")
    new_fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
    old_vehicles = old_fixture["expected_manifest"]["vehicles"]
    new_vehicles = new_fixture["expected_manifest"]["vehicles"]
    assert all(new_vehicles[k] == v for k, v in old_vehicles.items() if k != "electric")
    old_fixture["expected_manifest"]["physics_version"] = "arcade-planar-0.75"
    old_fixture["expected_manifest"]["vehicles"]["electric"] = new_vehicles["electric"]
    assert old_fixture == new_fixture
    canonical = read_json("canonical-verification.json")
    assert canonical["input_count"] == canonical["time_ticks"] == 34805
    assert canonical["time_ms"] == 290035 and len(canonical["lap_ticks"]) == 5
    assert canonical["electric"] == new_vehicles["electric"]
    assert (OUT / "canonical-race.json").read_bytes() == (OUT / "over-under-race.json").read_bytes()
    old_circles = json.loads((ROOT / "docs/evidence/electric-driving-character-2026-10-26/continuous-handling.json").read_text())["metrics"]["circles"]
    circles = read_json("continuous-handling.json")["metrics"]["circles"]
    assert len(circles) == 18
    assert all(v["after"]["radius"] == old_circles[k]["after"]["radius"] for k, v in circles.items())
    slide = read_json("slide-access.json")
    assert slide["checks"] == 518 and slide["failures"] == 0

    changes = {}
    runtime = ["game/resources/cars/electric.tres", "game/vehicle/vehicle_simulation.gd",
               "game/vehicle/handling_config.gd", "backend/tests/fixtures/verified_oval.json",
               "backend/tests/test_verifier.py"]
    candidates = runtime + [p for p in initial["sources"] if p.startswith("game/tests/test_electric")]
    for rel in candidates:
        path = ROOT / rel
        base = OUT / "before" / rel.replace("/", "__")
        if path.read_bytes() != base.read_bytes():
            changes[rel] = (base.read_text(encoding="utf-8-sig"), path.read_text(encoding="utf-8-sig"))
    for rel in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
        text = (ROOT / rel).read_text(encoding="utf-8")
        start = "<!-- ELECTRIC-SLIDE-ACCESS-20261027 -->"
        end = "<!-- /ELECTRIC-SLIDE-ACCESS-20261027 -->"
        entry = text[text.index(start):text.index(end) + len(end)] + "\n\n"
        base = text.replace(entry, "", 1)
        (OUT / (rel.replace("/", "__") + ".scoped-base")).write_text(base, encoding="utf-8")
        changes[rel] = (base, text)
    for rel in ["game/tests/probe_electric_slide_access.gd", "game/tests/probe_electric_slide_access.gd.uid",
                "game/tests/test_electric_slide_access.gd", "game/tests/test_electric_slide_access.gd.uid",
                "docs/ELECTRIC_SLIDE_ACCESS_2026_10_27.md"]:
        changes[rel] = ("", (ROOT / rel).read_text(encoding="utf-8"))
    patch = []
    for rel, (base, text) in sorted(changes.items()):
        patch.extend(difflib.unified_diff(base.splitlines(keepends=True), text.splitlines(keepends=True),
                                         fromfile=f"a/{rel}" if base else "/dev/null", tofile=f"b/{rel}", n=2))
    (OUT / "checkpoint.patch").write_text("".join(patch), encoding="utf-8")
    command = ["git", "-c", "core.autocrlf=false", "apply", "--reverse", "--check", "--ignore-space-change", str(OUT / "checkpoint.patch")]
    checked = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    assert checked.returncode == 0, checked.stderr
    retained = []
    for path in sorted(OUT.rglob("*.log")):
        text = read_log(path)
        if "FAIL:" in text or "1 error" in text:
            retained.append(path.relative_to(ROOT).as_posix())
    report = {
        "requirements": ["ESA01", "ESA02", "ESA03", "R01", "Q01"],
        "date": "2026-10-27", "handling_version": "electric-18", "physics_version": "arcade-planar-0.75",
        "changed_fields": delta, "results": results, "canonical_verification": canonical,
        "slide_access": slide["metrics"], "held_radius_results_exact": 18,
        "exact_sources": exact, "other_vehicle_identities_exact": 6,
        "default_integrator_tick_comparisons": "1200 ticks each for all six other cars and electric-17",
        "prior_evidence_artifacts_exact": len(initial["prior_evidence"]),
        "retained_failure_logs": retained,
        "source_hashes": {rel: sha(ROOT / rel) for rel in sorted(changes)},
        "evidence_hashes": {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(OUT.rglob("*"))
                            if p.is_file() and p.name not in ["report.json", "checkpoint.patch"]},
        "checkpoint": {"path": f"{PREFIX}/checkpoint.patch", "sha256": sha(OUT / "checkpoint.patch"),
                       "reverse_check": {"command": command, "exit_code": checked.returncode},
                       "staged": False, "committed": False, "scope": "task sources and documentation; evidence retained separately"},
        "limits": ["Synthetic input and artificial driving; owner keyboard/controller feel acceptance remains",
                   "Desktop renderers; no physical-controller hardware or device attachment check/test",
                   "Hitches remain; no phone or frame-time claim", "Reload/rebuild and matching verifier rollout required",
                   "No APK, real purchase/authentication, owner-save mutation, deployment, staging, commit, merge or owner-process restart"],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Audited {len(results)} final results, {len(changes)} scoped sources, {len(initial['prior_evidence'])} unchanged prior artifacts.")


if __name__ == "__main__":
    main()
