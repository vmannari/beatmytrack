"""Record and independently apply the scoped electric-6 braking delta."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
REL = OUT.relative_to(ROOT)
META = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
COMMON = ["game/resources/cars/electric.tres", "game/vehicle/vehicle_simulation.gd",
          "game/vehicle/handling_config.gd", "backend/tests/test_verifier.py",
          "backend/tests/fixtures/verified_oval.json"] + [
    f"game/tests/test_electric_{name}.gd" for name in
    ["power", "power_balance", "steering_response", "car", "car_ui", "one_pedal"]]
NEW = ["game/tests/test_electric_brake_release.gd", "game/tests/test_electric_brake_release.gd.uid",
       "docs/ELECTRIC_BRAKE_RELEASE_2026_10_25.md"]


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args, cwd, code=0):
    result = subprocess.run(args, cwd=cwd, capture_output=True)
    assert result.returncode == code, (args, result.stderr.decode(errors="replace"))
    return result.stdout


def main():
    for path in OUT.rglob("*.log"):
        data = path.read_bytes()
        content = data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig")
        write(path, content.encode())
    assert "72 passed, 2 deselected, 6 warnings" in (OUT / "backend.log").read_text()
    parser = (OUT / "parser-console.log").read_text()
    assert "SCRIPT_PARSE: 1167 scripts, 0 failures" in parser
    for name, tag in {"native": "ELECTRIC_UI: 60 checks, 0 failures",
                      "mobile": "ELECTRIC_UI: 60 checks, 0 failures",
                      "laps": "ELECTRIC_POWER_LAPS: 6 checks, 0 failures"}.items():
        assert tag in (OUT / (name + "-console.log")).read_text(), name
    assert "ERROR" not in (OUT / "import-console.log").read_text()
    results = {}
    for name, count in {"release": 38, "balance": 22, "power": 19, "response": 86,
                        "turning": 61, "handling": 60, "one-pedal": 63}.items():
        result = json.loads((OUT / (name + ".json")).read_text())
        assert result["failures"] == 0 and result["checks"] == count, name
        results[name] = result
    manifest = json.loads((OUT / "manifest.json").read_text())
    prior = json.loads((OUT / "before/backend__tests__fixtures__verified_oval.json.txt").read_text())
    fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
    fixture["expected_manifest"]["vehicles"]["electric"] = prior["expected_manifest"]["vehicles"]["electric"]
    fixture["expected_manifest"]["physics_version"] = prior["expected_manifest"]["physics_version"]
    assert fixture == prior
    unchanged = [car for car, tune in manifest["vehicles"].items()
                 if car != "electric" and tune == prior["expected_manifest"]["vehicles"][car]]
    assert len(unchanged) == 6
    frozen = {}
    for name in ["game/vehicle/electric_coachwork.gd", "game/input/driver_input.gd"]:
        before = OUT / "before" / (name.replace("/", "__") + ".txt")
        assert before.read_bytes() == (ROOT / name).read_bytes(), name
        frozen[name] = sha(before)
    resource = "game/resources/cars/electric.tres"
    before = (OUT / "before" / (resource.replace("/", "__") + ".txt")).read_text()
    assert before.replace('version = "electric-5"', 'version = "electric-6"').replace(
        'regeneration = 14.0', 'regeneration = 26.0') == (ROOT / resource).read_text()
    block = (
        "<!-- ELECTRIC-BRAKE-RELEASE-20261025 -->\n"
        "## Braking-strength electric pedal release override (2026-10-25)\n"
        "2026-10-25 EBR01-EBR04/R01/Q01: Electric-6 full release blends automatic four-wheel friction braking "
        "with regeneration, replacing the rear-motor ceiling for single-pedal lift only. Requested26m/s2 "
        "versus14 gives actual72km/h stop0.767s/7.563m versus1.417s/14.044m;100km/h1.067s/14.601m. "
        "Immediate actual-Game first-tick braking, exact zero hold, reverse, no brake/handbrake pedal and "
        "D/R remain. Softer launch and powered steering are tick-exact versus old0.68; six other cars "
        "match2400 power/coast/brake/handbrake ticks each. Release38/electric60/one-pedal63/power19/balance22/"
        "response86/turn61/laps6/actual-App60Compatibility/60desktopMobile, backend72pass/2existing exclusions, "
        "actual13270input five-lap server replay and parser1167/import pass. Initial compact-frame test "
        "error is retained and corrected without relaxing invariants. Physics0.69/configd3ea4b2a fence changed "
        "canonical braking; six other configuration hashes/model/input remain exact. Commands, hashes and "
        "task-only Git-checked checkpoint: docs/ELECTRIC_BRAKE_RELEASE_2026_10_25.md and "
        "docs/evidence/electric-brake-release-2026-10-25/report.json. Client reload, matching client/verifier "
        "rollout and owner/device braking feel remain; no attachment/device test, APK, live mutation, "
        "purchase, deployment or owner-process restart. Concurrent work preserved.\n"
        "<!-- /ELECTRIC-BRAKE-RELEASE-20261025 -->\n\n")
    for name in META:
        baseline = re.sub(rb"<!-- ELECTRIC-BRAKE-RELEASE-20261025 -->.*?<!-- /ELECTRIC-BRAKE-RELEASE-20261025 -->\r?\n\r?\n",
                          b"", (ROOT / name).read_bytes(), flags=re.S)
        write(OUT / "checkpoint-base" / name, baseline)
        write(ROOT / name, block.encode() + baseline)
    for name in COMMON:
        write(OUT / "checkpoint-base" / name,
              (OUT / "before" / (name.replace("/", "__") + ".txt")).read_bytes())
    report = {
        "date": "2026-10-25", "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "requirements": {"EBR01": "braking-strength immediate accelerator release",
                         "EBR02": "complete controlled stop and hold", "EBR03": "preserve softened RWD power/steering/cap",
                         "EBR04": "version and independently verify canonical braking"},
        "version": manifest["vehicles"]["electric"], "physics_version": manifest["physics_version"],
        "results": results, "other_checks": {"laps": 6, "compatibility_ui": 60, "desktop_mobile_ui": 60,
                                              "backend_pass": 72, "backend_deselected": 2, "parser_scripts": 1167,
                                              "normal_import": "pass"},
        "canonical_verification": json.loads((OUT / "canonical-verification.json").read_text()),
        "unchanged_other_car_configs": unchanged, "unchanged_source_sha256": frozen,
        "initial_outcomes": ["First new regression assumed zero-handbrake frames retained four channels; valid compact three-channel encoding interrupted test. Corrected its encoding check; all38 checks pass without relaxed braking thresholds"],
        "commands_document": NEW[-1], "changed_files": COMMON + NEW + META,
        "limits": ["Client reload and matching client/verifier rollout required; shared physics version changes board identity",
                   "Owner/device braking feel remains", "No attachment check/device test, APK, live mutation, purchase, deployment or owner-process restart",
                   "Unavailable PostgreSQL and historical physics-050 ghost defect are existing explicit exclusions",
                   "Manual-stepping native hitch diagnostics are not a performance benchmark"],
        "checkpoint": {"path": str(REL / "checkpoint.patch").replace("\\", "/"),
                       "baseline": "task-start sources; current concurrent metadata with only this task marker removed",
                       "git_apply_check": False, "byte_exact": False},
    }
    evidence = [str(path.relative_to(ROOT)).replace("\\", "/") for path in OUT.rglob("*")
                if path.is_file() and path.name not in ["checkpoint.patch", "report.json"]
                and "__pycache__" not in path.parts]
    files = sorted(set(COMMON + NEW + META + evidence))
    report["sha256"] = {name: sha(ROOT / name) for name in files}
    record = OUT / "report.json"
    write(record, (json.dumps(report, indent=2) + "\n").encode())
    index = 1
    while (ROOT / f"build/electric-release-checkpoint-{index}").exists():
        index += 1
    stage = ROOT / f"build/electric-release-checkpoint-{index}"
    before, after = stage / "before", stage / "after"
    for name in COMMON + META:
        write(before / name, (OUT / "checkpoint-base" / name).read_bytes())
    paths = files + [str(REL / "report.json").replace("\\", "/")]
    for name in paths:
        write(after / name, (ROOT / name).read_bytes())
    patch = OUT / "checkpoint.patch"

    def make_patch():
        diff = run(["git", "-c", "core.autocrlf=false", "diff", "--no-index", "--no-renames",
                    "--binary", "--", "before", "after"], stage, 1)
        lines = []
        for line in diff.splitlines(keepends=True):
            if line.startswith((b"diff --git ", b"--- ", b"+++ ")):
                for source, target in [(b"a/before/", b"a/"), (b"b/after/", b"b/"),
                                       (b"a/after/", b"a/"), (b"b/before/", b"b/")]:
                    line = line.replace(source, target)
            lines.append(line)
        patch.write_bytes(b"".join(lines))

    def verify(label):
        target = stage / label
        shutil.copytree(before, target)
        run(["git", "init", "-q"], target)
        run(["git", "config", "core.autocrlf", "false"], target)
        run(["git", "apply", "--check", str(patch)], target)
        run(["git", "apply", str(patch)], target)
        for name in paths:
            assert (target / name).read_bytes() == (after / name).read_bytes(), name

    make_patch()
    verify("verify1")
    report["checkpoint"].update(git_apply_check=True, byte_exact=True, changed_paths=len(paths))
    write(record, (json.dumps(report, indent=2) + "\n").encode())
    shutil.copyfile(record, after / REL / "report.json")
    make_patch()
    verify("verify2")
    for name, value in report["sha256"].items():
        assert sha(ROOT / name) == value, name
    print(json.dumps({"checkpoint": report["checkpoint"], "hashes_verified": len(files),
                      "patch_bytes": patch.stat().st_size}))


if __name__ == "__main__":
    main()
