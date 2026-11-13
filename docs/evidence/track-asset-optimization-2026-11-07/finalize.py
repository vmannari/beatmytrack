"""Create the task-only review checkpoint; never stage or change repository state."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import zipfile

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    audited = json.loads((BASE / "validation-final-hashes.json").read_text())
    assert all(digest(ROOT / p) == value for p, value in audited.items()), "Audited scenery inputs changed"
    reports = {}
    for mode, checks in [("headless", 370), ("gl_compatibility", 261), ("mobile", 261)]:
        value = json.loads((BASE / mode / "report.json").read_text())
        assert value["checks"] == checks and value["failures"] == 0
        if mode != "headless":
            assert len(value["rows"]) == 36
            for row in value["rows"]:
                stem = f'{row["theme"]}-{row["kind"]}-{row["view"]}'
                for phase in ["before", "after"]:
                    assert (BASE / mode / f"{stem}-{phase}.png").is_file()
                assert row["before_draws"] == row["after_draws"]
        reports[mode] = value

    markers = {
        "SPATIAL_WORKER_OBJECT_RANGES": 71, "SPATIAL_MESH_CHUNKS": 34,
        "PROP_REFINEMENT_TESTS": 909, "RACE_LOADING_OPTIMISATION": 20,
        "SELECTIVE_BUDGET": 12, "DRIVING_TESTS": 72,
    }
    found = {}
    preflight_attempts = []
    log_index = []
    log_folder = BASE / "logs"
    log_folder.mkdir(exist_ok=True)
    started = (BASE / "validation-start-hashes.json").stat().st_mtime
    for path in sorted((ROOT / "build/logs").glob("TestScript-*/test-script.log"), key=lambda x: x.stat().st_mtime):
        content = path.read_text(encoding="utf-8-sig", errors="replace")
        relevant = any(x in content for x in ["SCENERY_MESH_LODS", "SCENERY_LOD_BAKE", "SCENERY_SOURCE_DIFF", "test_scenery_lods_editor_retention"])
        relevant |= path.stat().st_mtime >= started and any(x in content for x in [*markers, "PREPARED_ASSETS", "test_editor_incremental_objects"])
        if not relevant:
            continue
        target = log_folder / (path.parent.name + ".log")
        shutil.copy2(path, target)
        outcomes = [line for line in content.splitlines() if re.search(r"(?:checks,|checks /).*failures|PREPARED_ASSETS|CrashHandlerException|SCRIPT ERROR:", line)]
        log_index.append({"path": target.relative_to(ROOT).as_posix(), "outcomes": outcomes})
        for match in re.finditer(r"PREPARED_ASSETS (\d+) resources; (\d+) checks, (\d+) failures", content):
            preflight_attempts.append({"path": target.relative_to(ROOT).as_posix(),"resources":int(match[1]),"checks":int(match[2]),"failures":int(match[3])})
        for marker, expected in markers.items():
            if path.stat().st_mtime >= started and re.search(re.escape(marker) + rf"\D+{expected} checks, 0 failures", content):
                found[marker] = target.relative_to(ROOT).as_posix()
    assert set(found) == set(markers), f"Missing passing regression logs: {set(markers) - set(found)}"
    before_crash = (BASE / "editor-before-control.log").read_text(errors="replace")
    assert "CrashHandlerException" in before_crash and "run_build_editor_tools" in before_crash
    assert "_place" in before_crash and "APP_READY" in before_crash
    assert len(json.loads((BASE / "vehicle-identity-independent-paths.json").read_text(encoding="utf-8-sig"))) == 11

    starting = json.loads((BASE / "start-hashes.json").read_text())
    modified = [name for name, value in starting.items() if digest(ROOT / name) != value]
    new_text = [
        "game/track/scenery_mesh_lods.gd", "game/tests/bake_scenery_mesh_lods.gd",
        "game/tests/test_scenery_mesh_lods.gd", "game/tests/test_scenery_lods_editor_retention.gd",
        "game/tests/probe_scenery_prepared_sources.gd", "docs/TRACK_ASSET_OPTIMIZATION_2026_11_07.md",
    ] + [p.relative_to(ROOT).as_posix() for p in [BASE / "run_validation.ps1", BASE / "make_comparisons.ps1", BASE / "check_vehicle_dependencies.ps1", Path(__file__).resolve()]]
    for name in list(new_text):
        uid = ROOT / (name + ".uid")
        if name.endswith(".gd") and uid.exists():
            new_text.append(uid.relative_to(ROOT).as_posix())
    assets = sorted((ROOT / "game/assets/scenery_lods_v1").glob("*.res"))
    assert len(assets) == 3 and sum(x.stat().st_size for x in assets) == 44901
    patch = []
    for name in modified + new_text:
        rebased = BASE / "before-current-concurrent" / name
        before = (rebased if rebased.exists() else BASE / "before" / name).read_text(encoding="utf-8") if name in modified else ""
        after = (ROOT / name).read_text(encoding="utf-8")
        lines = list(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True), fromfile="a/" + name if before else "/dev/null", tofile="b/" + name))
        assert all(line.rstrip("\r\n").rstrip() == line.rstrip("\r\n") for line in lines if line.startswith("+") and not line.startswith("+++")), name
        patch.extend(lines)
    output = "".join(patch).encode("utf-8")
    for asset in assets:
        relative = asset.relative_to(ROOT).as_posix()
        difference = subprocess.run(["git", "diff", "--no-index", "--binary", "--", "/dev/null", relative], cwd=ROOT, capture_output=True)
        assert difference.returncode == 1 and b"GIT binary patch" in difference.stdout, difference.stderr.decode(errors="replace")
        output += difference.stdout
    (BASE / "task-only.patch").write_bytes(output)
    own_files = [ROOT / name for name in modified + new_text] + assets
    with zipfile.ZipFile(BASE / "task-only-checkpoint.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in own_files:
            archive.write(path, "after/" + path.relative_to(ROOT).as_posix())
        for name in starting:
            archive.write(BASE / "before" / name, "before-task-start/" + name)
            rebased = BASE / "before-current-concurrent" / name
            archive.write(rebased if rebased.exists() else BASE / "before" / name, "before-owned-patch/" + name)
        archive.write(BASE / "task-only.patch", "task-only.patch")
    with zipfile.ZipFile(BASE / "task-only-checkpoint.zip") as archive:
        assert archive.testzip() is None
    total = sum(x["checks"] for x in reports.values()) + sum(markers.values())
    assert total == 2010
    receipt = {
        "requirements": ["TSO01", "TSO02", "TSO03", "TSO04"],
        "engine": "4.7.2.stable.official.ed1daf0bf",
        "focused_checks": {k: {"checks": v["checks"], "failures": v["failures"]} for k, v in reports.items()},
        "completed_passing_scoped_checks": total,
        "regressions": found,
        "native_static_cases": 72, "native_images": 144, "native_motion_frames": 192,
        "final_audited_input_hashes": audited,
        "concurrent_rebase": "concurrent-rebase.json",
        "task_files": {p.relative_to(ROOT).as_posix(): digest(p) for p in own_files},
        "prepared_assets_bytes": 44901,
        "logs": log_index,
        "prepared_car_preflight_attempts": preflight_attempts,
        "retained_limits": [
            "Legacy editor fixture lacked an await for deferred entry; task copy retains all assertions with the current API and original full-detail reference.",
            "Broader editor workflow crashes at native UI visibility after tyre placement in headless and Compatibility; exact task-start source control reproduces the same crash.",
            "Prepared-car preflight records 936, then 144, then 2 failures out of 1925; latest failures are the Hover Garage rest key/source receipt. All 11 production task paths are outside the actual car identity routing rules.",
            "Close visible master geometry is exact; shadow-detail selection produces small frame differences documented in the report.",
            "No device query/test, APK/export/install, owner-save/process change, live/backend request, deployment or main-index mutation.",
            "No proportional FPS, loading, memory or package-size improvement is claimed.",
        ],
        "checkpoint": "task-only-checkpoint.zip",
        "patch": "task-only.patch",
    }
    (BASE / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"{total} completed passing checks; {len(own_files)} task files; {len(log_index)} retained logs; checkpoint CRC valid")


if __name__ == "__main__":
    main()
