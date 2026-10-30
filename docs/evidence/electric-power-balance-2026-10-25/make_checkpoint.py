"""Record and independently apply the scoped electric-5 balance delta."""
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
COMMON = ["game/resources/cars/electric.tres", "backend/tests/fixtures/verified_oval.json"] + [
    f"game/tests/test_electric_{name}.gd" for name in
    ["power", "turning", "steering_response", "car", "one_pedal"]]
NEW = ["game/tests/test_electric_power_balance.gd", "game/tests/test_electric_power_balance.gd.uid",
       "docs/ELECTRIC_POWER_BALANCE_2026_10_25.md"]


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
    # Preserve native outcomes and the initial interrupted parser/log diagnostics.
    cutoff = (OUT / "before/game__resources__cars__electric.tres.txt").stat().st_mtime
    for path in (ROOT / "build/logs").glob("TestScript-*/test-script.log"):
        if path.stat().st_mtime < cutoff:
            continue
        content = path.read_text(errors="replace")
        if any(tag in content for tag in ["ELECTRIC_", "ONE_PEDAL:"]) or path.parent.name in [
                "TestScript-35060", "TestScript-36016", "TestScript-38492",
                "TestScript-38376", "TestScript-32856", "TestScript-39828"]:
            write(OUT / "logs" / (path.parent.name + ".log"), path.read_bytes())
    import_log = ROOT / "build/logs/Import-27136/import.log"
    assert "ERROR" not in import_log.read_text(errors="replace")
    write(OUT / "logs/Import-27136.log", import_log.read_bytes())
    for name in ["backend.log", "response-console.log", "turning-console.log"]:
        path = OUT / name
        content = path.read_bytes()
        content = content.decode("utf-16" if content.startswith(b"\xff\xfe") else "utf-8-sig")
        write(path, content.encode())
    assert "72 passed, 2 deselected, 6 warnings" in (OUT / "backend.log").read_text()
    assert "SCRIPT_PARSE: 1165 scripts, 0 failures" in (OUT / "logs/TestScript-36016.log").read_text()
    results = {}
    for name, count in {"balance": 22, "power": 19, "response": 86, "turning": 61,
                        "handling": 60, "one-pedal": 63}.items():
        result = json.loads((OUT / (name + ".json")).read_text())
        assert result["failures"] == 0 and result["checks"] == count, name
        results[name] = result
    manifest = json.loads((OUT / "manifest.json").read_text())
    prior = json.loads((OUT / "before/backend__tests__fixtures__verified_oval.json.txt").read_text())
    fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
    old_ev = prior["expected_manifest"]["vehicles"]["electric"]
    fixture["expected_manifest"]["vehicles"]["electric"] = old_ev
    assert fixture == prior
    unchanged = [car for car, tune in manifest["vehicles"].items()
                 if car != "electric" and tune == prior["expected_manifest"]["vehicles"][car]]
    assert len(unchanged) == 6
    frozen = {}
    for name in ["game/vehicle/handling_config.gd", "game/vehicle/vehicle_simulation.gd",
                 "game/vehicle/electric_coachwork.gd"]:
        before = OUT / "before" / (name.replace("/", "__") + ".txt")
        assert before.read_bytes() == (ROOT / name).read_bytes(), name
        frozen[name] = sha(before)
    block = (
        "<!-- ELECTRIC-POWER-BALANCE-20261025 -->\n"
        "## Electric acceleration and regeneration balance override (2026-10-25)\n"
        "2026-10-25 EPB01-EPB04/R01/Q01: Electric-5 softens launch0to100 from1.017to1.525s, "
        "lowers top speed172.8to158.4km/h and strengthens immediate lift deceleration11.219to14.219m/s2. "
        "Exact released-pedal stop72km/h improves1.8to1.417s/17.842to14.044m, retaining zero hold, "
        "strict one pedal/no handbrake, saved-position D/R and quicker electric-4 steering fields. "
        "Balance22/power19/response86/turn61/electric60/one-pedal63/laps6/Garage-race59Compatibility/59desktopMobile, "
        "backend72pass/2existing exclusions, actual13186input five-lap server replay and parser1165/import pass. "
        "Owner correction supersedes prior aggressive launch/unchanged-cap targets; old steering references "
        "use the current propulsion/cap with all previous steering bounds retained. Initial concurrent Desert "
        "capture parser interruption and nonfatal native logfile-open diagnostics are retained; sequential "
        "steering reruns and final full parser pass. EV hash11d98267, physics0.68, six other car entries, "
        "shared math and corrected model remain exact. Commands, hashes and task-only Git-checked checkpoint: "
        "docs/ELECTRIC_POWER_BALANCE_2026_10_25.md and docs/evidence/electric-power-balance-2026-10-25/report.json. "
        "Client reload, matching online verifier/config rollout and owner/device feel acceptance remain. "
        "No attachment/device test, APK, live mutation, purchase, deployment or owner-process restart; "
        "concurrent work preserved.\n<!-- /ELECTRIC-POWER-BALANCE-20261025 -->\n\n")
    for name in META:
        baseline = re.sub(rb"<!-- ELECTRIC-POWER-BALANCE-20261025 -->.*?<!-- /ELECTRIC-POWER-BALANCE-20261025 -->\r?\n\r?\n",
                          b"", (ROOT / name).read_bytes(), flags=re.S)
        write(OUT / "checkpoint-base" / name, baseline)
        write(ROOT / name, block.encode() + baseline)
    for name in COMMON:
        write(OUT / "checkpoint-base" / name,
              (OUT / "before" / (name.replace("/", "__") + ".txt")).read_bytes())
    report = {
        "date": "2026-10-25", "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "requirements": {"EPB01": "softer launch", "EPB02": "stronger immediate lift-off stop",
                         "EPB03": "slightly lower top speed", "EPB04": "retain sharp steering and one-pedal RWD"},
        "version": manifest["vehicles"]["electric"], "physics_version": manifest["physics_version"],
        "results": results, "other_checks": {"laps": 6, "compatibility_ui": 59, "desktop_mobile_ui": 59,
                                              "backend_pass": 72, "backend_deselected": 2, "parser_scripts": 1165,
                                              "normal_import": "pass"},
        "canonical_verification": json.loads((OUT / "canonical-verification.json").read_text()),
        "unchanged_other_car_configs": unchanged, "unchanged_source_sha256": frozen,
        "initial_outcomes": ["Initial whole-project parse interrupted by concurrently edited Desert capture closing parenthesis; corrected by concurrent work before subsequent read, final parser1165 passes",
                             "Three concurrent native logfile-open errors retained; assertion JSON passed, sequential steering/turning console reruns also pass",
                             "Prior launch/cap assertions explicitly superseded by owner; stronger regen/stop assertions and all steering bounds retained"],
        "commands_document": NEW[-1], "changed_files": COMMON + NEW + META,
        "limits": ["Client reload and matching online verifier/config rollout required", "Owner/device driving feel remains",
                   "No attachment check/device test, APK, live mutation, purchase, deployment or owner-process restart",
                   "Unavailable PostgreSQL and historical physics-050 ghost defect are established explicit exclusions",
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
    while (ROOT / f"build/electric-balance-checkpoint-{index}").exists():
        index += 1
    stage = ROOT / f"build/electric-balance-checkpoint-{index}"
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
