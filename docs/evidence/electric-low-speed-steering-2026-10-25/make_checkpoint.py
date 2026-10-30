"""Record and independently apply the scoped electric-7 low-speed steering delta."""
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
    ["power", "power_balance", "steering_response", "brake_release"]]
NEW = ["game/tests/test_electric_low_speed_steering.gd", "game/tests/test_electric_low_speed_steering.gd.uid",
       "docs/ELECTRIC_LOW_SPEED_STEERING_2026_10_25.md"]


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
    assert "SCRIPT_PARSE: 1172 scripts, 0 failures" in (OUT / "parser-console.log").read_text()
    for name, tag in {"native": "ELECTRIC_UI: 60 checks, 0 failures",
                      "mobile": "ELECTRIC_UI: 60 checks, 0 failures",
                      "laps": "ELECTRIC_POWER_LAPS: 6 checks, 0 failures"}.items():
        assert tag in (OUT / (name + "-console.log")).read_text(), name
    assert "ERROR" not in (OUT / "import-console.log").read_text()
    results = {}
    for name, count in {"low-speed": 63, "release": 38, "balance": 22, "power": 19,
                        "response": 86, "turning": 61, "handling": 60, "one-pedal": 63}.items():
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
    for name in ["game/vehicle/electric_coachwork.gd", "game/vehicle/car_visual.gd",
                 "game/input/driver_input.gd", "game/resources/cars/kart.tres"]:
        before = OUT / "before" / (name.replace("/", "__") + ".txt")
        assert before.read_bytes() == (ROOT / name).read_bytes(), name
        frozen[name] = sha(before)
    resource = "game/resources/cars/electric.tres"
    before = (OUT / "before" / (resource.replace("/", "__") + ".txt")).read_text()
    assert before.replace('version = "electric-6"', 'version = "electric-7"').replace(
        'high_speed_steering_reduction = 0.25', 'high_speed_steering_reduction = 0.25\nlow_speed_steering_scale = 0.60') == (ROOT / resource).read_text()
    block = (
        "<!-- ELECTRIC-LOW-SPEED-STEERING-20261025 -->\n"
        "## Calmer electric steering at very low speed override (2026-10-25)\n"
        "2026-10-25 ELS01-ELS04/R01/Q01: Electric-7 uses0.60 steering-angle scale through2m/s, "
        "smoothly fading to the accepted full response at8m/s(28.8km/h). Actual0.2s full-lock direction "
        "response falls48.7% at3.6km/h,45.2% at10.8,26.2% at18 and4.2% at25.2, with symmetric "
        "forward/reverse touch control. All135 high-speed step cases and four full-second cornering "
        "runs are tick-exact versus accepted physics0.69/electric-6. Straight softened launch/strong "
        "release stop0.767s/7.563m remain exact; six other cars match2400 ticks each. Low-speed63/release38/"
        "electric60/one-pedal63/power19/balance22/response86/turn61/laps6/actual-App60Compatibility/60desktopMobile, "
        "backend72pass/2existing exclusions, actual13270input five-lap server replay and parser1172/import pass. "
        "Owner low-speed correction supersedes the old low-speed powered-turn equivalence assertion; "
        "straight power and exact high-speed turns are checked separately without weaker tolerances. "
        "Physics0.70/config7d10eaf9 pin the change; six other config hashes including kart-5 and exact "
        "model/presentation/input remain. Commands, hashes and task-only Git-checked checkpoint: "
        "docs/ELECTRIC_LOW_SPEED_STEERING_2026_10_25.md and "
        "docs/evidence/electric-low-speed-steering-2026-10-25/report.json. Client reload, matching "
        "client/verifier rollout and owner/device steering feel remain; no attachment/device test, APK, "
        "live mutation, purchase, deployment or owner-process restart. Concurrent work preserved.\n"
        "<!-- /ELECTRIC-LOW-SPEED-STEERING-20261025 -->\n\n")
    for name in META:
        baseline = re.sub(rb"<!-- ELECTRIC-LOW-SPEED-STEERING-20261025 -->.*?<!-- /ELECTRIC-LOW-SPEED-STEERING-20261025 -->\r?\n\r?\n",
                          b"", (ROOT / name).read_bytes(), flags=re.S)
        write(OUT / "checkpoint-base" / name, baseline)
        write(ROOT / name, block.encode() + baseline)
    for name in COMMON:
        write(OUT / "checkpoint-base" / name,
              (OUT / "before" / (name.replace("/", "__") + ".txt")).read_bytes())
    report = {
        "date": "2026-10-25", "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "requirements": {"ELS01": "calmer parking-speed steering",
                         "ELS02": "retain accepted higher-speed response", "ELS03": "preserve power/braking/RWD/cap/controls",
                         "ELS04": "version and independently verify canonical steering"},
        "version": manifest["vehicles"]["electric"], "physics_version": manifest["physics_version"],
        "results": results, "other_checks": {"laps": 6, "compatibility_ui": 60, "desktop_mobile_ui": 60,
                                              "backend_pass": 72, "backend_deselected": 2, "parser_scripts": 1172,
                                              "normal_import": "pass"},
        "canonical_verification": json.loads((OUT / "canonical-verification.json").read_text()),
        "unchanged_other_car_configs": unchanged, "unchanged_source_sha256": frozen,
        "initial_outcomes": [],
        "test_contract_update": "Owner intentionally changes parking-speed steering. Prior release suite retains exact straight power; new63-check suite verifies the changed low-speed response and135 exact high-speed cases plus four full-second corners. No braking/high-speed/grip/speed tolerances relaxed.",
        "commands_document": NEW[-1], "changed_files": COMMON + NEW + META,
        "limits": ["Client reload and matching client/verifier rollout required; shared physics version changes board identity",
                   "Owner/device steering feel remains", "No attachment check/device test, APK, live mutation, purchase, deployment or owner-process restart",
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
    while (ROOT / f"build/electric-low-speed-checkpoint-{index}").exists():
        index += 1
    stage = ROOT / f"build/electric-low-speed-checkpoint-{index}"
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
