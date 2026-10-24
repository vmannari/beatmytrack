"""Retain this task's explicit test receipts and generate a scoped review patch."""
from __future__ import annotations

import difflib
import hashlib
import json
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def head(path: str) -> bytes:
    result = subprocess.run(["git", "show", "HEAD:" + path], cwd=ROOT, capture_output=True)
    return result.stdout if result.returncode == 0 else b""


def normal(data: bytes) -> str:
    return data.decode("utf-8-sig").replace("\r\n", "\n")


def log_text(path: Path) -> str:
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig")


# Explicitly selected task commands, not other agents' concurrently running tests.
RUNS = {
    18904: "test_condition_store", 18684: "test_condition_store",
    4736: "test_paint_preparation", 24164: "test_paint_preparation",
    37864: "test_paint_preparation", 16408: "test_dynamic_prop_work",
    20764: "test_tyre_equivalence", 31812: "test_car_wash",
    23012: "test_driving", 30632: "test_checkpoint_rules",
    31352: "test_tyres_and_load", 34896: "test_breakable_props",
    34640: "test_burning_barrel", 27340: "test_rewind",
    22156: "test_native_winter_raster", 23156: "test_app",
    24824: "test_editor_preparation", 23528: "test_compiler_raster",
    34968: "test_script_parse", 13180: "test_breakable_contract",
    26572: "test_surface_modes", 21388: "test_condition_store",
    7004: "test_paint_preparation", 25384: "test_dynamic_prop_work",
    10760: "test_race_hitch_monitor", 19876: "test_garage_wash_surfaces",
    37004: "test_personal_ghosts", 31060: "profile_gameplay_f01_f03",
    33484: "test_dynamic_prop_work", 15008: "test_car_wash",
    14184: "test_cars", 18224: "test_handling", 6180: "test_bridge_contacts",
    26000: "test_road_cache", 9884: "test_achievement_notification",
    4996: "test_condition_store", 28120: "test_paint_preparation",
    740: "test_dynamic_prop_work", 18108: "test_script_parse",
    33524: "test_condition_store", 36780: "test_condition_store",
    32600: "test_condition_store", 27636: "test_records",
    6884: "test_script_parse",
}
logs = OUT / "logs"
logs.mkdir(exist_ok=True)
receipts = []
for pid, name in RUNS.items():
    assert (ROOT / "game/tests" / (name + ".gd")).exists(), name
    folder = ROOT / "build/logs" / f"TestScript-{pid}"
    source = folder / "test-script.log"
    text = source.read_text(encoding="utf-8-sig")
    renderer = "mobile" if "Forward Mobile" in text else "gl_compatibility" if "Compatibility -" in text else "headless"
    target = logs / f"{pid}-{name}-{renderer}.log"
    shutil.copyfile(source, target)
    identity = folder / "client-build-identity.json"
    if identity.exists():
        shutil.copyfile(identity, target.with_suffix(".identity.json"))
    summaries = [line for line in text.splitlines() if re.search(r"checks[=: ]+\d+.*failures|\d+ checks, \d+ failures|SCRIPT_PARSE:|TYRE_EQUIVALENCE:", line, re.I)]
    command = f"powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/{name}.gd"
    if renderer != "headless":
        command += f" -Graphical -RenderingMethod {renderer}"
    if name == "test_car_wash" and renderer != "headless":
        command += " -TestArgument '--evidence-root=res://../docs/evidence/gameplay-f01-f03-2026-10-23'"
    receipts.append({"script": name, "renderer": renderer, "command": command,
                     "log": target.relative_to(OUT).as_posix(), "summary": summaries,
                     "failures": [line for line in text.splitlines() if line.startswith("FAIL:")],
                     "sha256": digest(source.read_bytes())})

import_log = ROOT / "build/logs/Import-21080/import.log"
assert import_log.exists()
shutil.copyfile(import_log, logs / "final-import.log")
assert "ERROR:" not in import_log.read_text(encoding="utf-8-sig")
hitch = ROOT / "build/race-hitch-tests/23012/observed-save.json"
assert hitch.exists()
shutil.copyfile(hitch, OUT / "observed-injected-save.json")

for filename in ["surface-modes-task-original.log", "breakable-contract-task-original.log"]:
    assert (OUT / filename).exists()
current_failures = {r["script"]: r["failures"] for r in receipts if r["script"] in ["test_surface_modes", "test_breakable_contract"]}
reproductions = []
for script, filename in [("test_surface_modes", "surface-modes-task-original.log"), ("test_breakable_contract", "breakable-contract-task-original.log")]:
    original = [line for line in log_text(OUT / filename).splitlines() if line.startswith("FAIL:")]
    assert original == current_failures[script], script
    reproductions.append({"script": script, "identical_failure_count": len(original),
                          "failure_lines_sha256": digest("\n".join(original).encode()), "original_log": filename,
                          "disposition": "Pre-existing; assertions retained, outside requested fixes."})

before = json.loads((OUT / "before.json").read_text(encoding="utf-8-sig"))
before_by_path = {row["path"]: row for row in before}
runtime = [
    "game/core/game.gd", "game/persistence/local_records.gd", "game/persistence/condition_store.gd",
    "game/vehicle/vehicle_condition.gd", "game/vehicle/light_props.gd", "game/vehicle/loose_tyres.gd",
    "game/editor/track_compiler.gd", "game/editor/prepared_track_cache.gd",
    "game/track/native_track.gd", "game/track/road_kerbs.gd", "game/track/snow_banks.gd",
    "native/track_geometry/raster_geometry.hpp", "native/track_geometry/track_geometry.cpp",
    "native/track_geometry/PROVENANCE.md", "game/platform/track_geometry/track_geometry.gdextension",
]
new = ["game/tests/test_condition_store.gd", "game/tests/test_paint_preparation.gd",
       "game/tests/test_dynamic_prop_work.gd", "game/tests/profile_gameplay_f01_f03.gd",
       "docs/GAMEPLAY_F01_F03_2026_10_23.md"]
new += [p.relative_to(ROOT).as_posix() for p in (ROOT / "game/tests/fixtures/gameplay_f01_f03_before").iterdir() if p.is_file()]
for script in ["game/persistence/condition_store.gd"] + [p for p in new if p.endswith(".gd")]:
    uid = script + ".uid"
    if (ROOT / uid).exists():
        new.append(uid)
scope = runtime + ["game/tests/test_race_hitch_monitor.gd"] + new + ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "docs/GAMEPLAY_AUDIT_2026_10_23.md"]
patch = []
manifest = []
for path in dict.fromkeys(scope):
    current = (ROOT / path).read_bytes()
    if path in before_by_path:
        original = (OUT / "before" / path.replace("/", "__")).read_bytes()
        assert digest(original) == before_by_path[path]["sha256"]
        origin = "retained task-start source"
    elif path in new or path == "game/persistence/condition_store.gd":
        original = b""
        origin = "new file"
    elif path in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
        body = normal(current)
        assert "GPA-F01" in body.split("\n\n", 1)[0]
        original = body.split("\n\n", 1)[1].encode()
        origin = "current shared document minus this task's prefix; concurrent edits preserved"
    elif path == "docs/GAMEPLAY_AUDIT_2026_10_23.md":
        body = normal(current)
        followup = next(line for line in body.splitlines() if line.startswith("Follow-up: the owner subsequently"))
        original = body.replace(followup + "\n\n", "", 1).encode()
        origin = "audit before follow-up status link"
    else:
        original = head(path)
        origin = "HEAD; path was clean at task start"
    patch.extend(difflib.unified_diff(normal(original).splitlines(True), normal(current).splitlines(True), fromfile="a/"+path if original else "/dev/null", tofile="b/"+path))
    manifest.append({"path": path, "bytes": len(current), "sha256": digest(current),
                     "before_sha256": digest(original) if original else None, "baseline": origin})
for name, source in [("local_records", "game/persistence/local_records.gd"), ("track_compiler", "game/editor/track_compiler.gd"),
                     ("road_kerbs", "game/track/road_kerbs.gd"), ("light_props", "game/vehicle/light_props.gd"), ("loose_tyres", "game/vehicle/loose_tyres.gd")]:
    assert digest((ROOT / f"game/tests/fixtures/gameplay_f01_f03_before/{name}.gd.txt").read_bytes()) == before_by_path[source]["sha256"]
(OUT / "task-only-source.patch").write_text("".join(patch), encoding="utf-8", newline="\n")

binaries = []
for name in ["bmt_track_geometry.windows.x86_64.c21fac59c70d.dll", "libbmt_track_geometry.android.arm64.so", "libbmt_track_geometry.android.x86_64.so"]:
    path = ROOT / "game/platform/track_geometry" / name
    binaries.append({"path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size, "sha256": digest(path.read_bytes())})

report = {
    "generated_utc": datetime.now(timezone.utc).isoformat(),
    "request": "Fix F01, F02 and F03", "requirements": ["GPA-F01", "GPA-F01-R", "GPA-F02", "GPA-F03", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "final_build_identity": (ROOT / "game/core/build_identity.gd").read_text(),
    "environment": {"platform":"Windows", "graphical_device":"NVIDIA GeForce RTX 3090", "CPU_model":"not recorded", "profiles":"isolated APPDATA under build/gameplay-fixes-2026-10-23"},
    "test_receipts": receipts, "preexisting_reproductions": reproductions,
    "final_import": {"command":"powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import", "log":"logs/final-import.log", "result":"passed"},
    "paired_profile": {"file":"paired-profile.json", "command":"powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_gameplay_f01_f03.gd", "note":"Desktop microbenchmarks, no Android/FPS/thermal claims. Timed before the final load-only confirmed/live mirror correction; timed queue/solver/raster functions unchanged."},
    "native": {"command":"powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BuildTrackGeometry -NativePlatform all", "log":"native-build.log", "binaries":binaries, "godot_cpp":"e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77", "Android":"NDK r28b, API24, both architectures, ELF LOAD alignment 0x4000", "old_library_validation":["old-library-test_compiler_raster.log", "old-library-test_native_winter_raster.log"]},
    "corrections": [
        "Replaced initial RefCounted destruction-hook approach with weak-owner, tree-owned writer lifecycle; final tests prove release/join.",
        "Fixed test JSON numeric normalization and used quiet JSON parsing for intentionally corrupt files.",
        "Cancellation fixture requests cancellation within the existing native callback sampling cadence; all cancellation assertions retained.",
        "Initial isolated original/old-library commands lacked a historical docs junction or report directory; stopped only those owned processes and reran after test-environment correction.",
        "Incorrect test_car_condition_customisation name was rejected before execution; actual existing wash/Garage coverage passed.",
        "Final review fixed new-owner confirmed/live mirror ordering and added the 31st save test; final three-renderer save, records and parse checks passed.",
        "Removed only this task's unused intermediate ec17366f4140 DLL; prior shipped libraries retained.",
    ],
    "source_manifest":manifest,
    "checkpoint": {"source_patch":"task-only-source.patch", "sha256":digest((OUT / "task-only-source.patch").read_bytes()), "binary_reproduction":"BuildTrackGeometry command above; matching binaries are present in the workspace and fingerprinted here.", "scope":"Only requested fixes/tests/provenance/status additions. Existing concurrent source and shared-document edits excluded from patch."},
    "limitations":["No phone attachment check, device test, APK, deployment or live account/backend mutation.", "No universal stable60FPS claim; release-like Nord2 sustained15-20-minute CPU/GPU/thermal acceptance remains.", "F04 dense active tyre-pile scaling and the audit's other findings remain outside scope.", "Unique paint still costs coverage-proportional work; cancellation is cooperative, not a hard real-time deadline.", "Synchronous PB/result commits remain; final cosmetic lifecycle barriers can wait for the small sidecar IO.", "Atomic files and backup recovery do not promise preserving an in-flight cosmetic update after forced process termination."],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
print(json.dumps({"receipts":len(receipts), "source_files":len(manifest), "binary_files":len(binaries), "checkpoint_sha256":report["checkpoint"]["sha256"]}))
