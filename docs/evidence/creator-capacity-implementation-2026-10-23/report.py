"""Index actual capacity receipts and fingerprint the reviewable source checkpoint."""
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read_log(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")

capacity = {}
for mode in ("headless", "gl_compatibility", "mobile"):
    log = HERE / ("test_creator_capacity-"+mode+".log")
    rows = [json.loads(line.split("CREATOR_CAPACITY ", 1)[1]) for line in read_log(log).splitlines()
            if line.startswith("CREATOR_CAPACITY {")]
    assert rows[-1]["stage"] == "complete" and rows[-1]["failures"] == 0
    result = {"checks": rows[-1]["checks"], "failures": 0, "rows": rows,
              "log": log.name, "exit": 0}
    (HERE / ("capacity-results-"+mode+".json")).write_text(json.dumps(result, indent=2)+"\n")
    capacity[mode] = result

regression = {}
for log in sorted(HERE.glob("test_*.log")):
    if log.name.startswith("test_creator_capacity-"):
        continue
    content = read_log(log)
    summaries = [line for line in content.splitlines()
                 if re.search(r"(?:checks[=, ]|scripts,|comparisons passed)", line)
                 and not line.startswith("EDITOR_T05_T11 {")]
    errors = [line for line in content.splitlines()
              if re.search(r"(?:^| : )(?:SCRIPT ERROR:|ERROR:|FAIL:)", line)
              and "Failed to read the root certificate store" not in line]
    regression[log.name] = {"summaries": summaries, "unexpected_diagnostics": errors,
                            "passed": bool(summaries) and not errors
                            and not any(re.search(r"[1-9]\d* failures", s) for s in summaries)}

checkpoint = json.loads((HERE / "checkpoint.json").read_text()) if (HERE / "checkpoint.json").exists() else None
images = {p.name: {"bytes": p.stat().st_size, "sha256": digest(p)} for p in HERE.glob("tyres-*.png")}
for mode in ("gl_compatibility", "mobile"):
    assert images["tyres-before-"+mode+".png"]["sha256"] == images["tyres-after-"+mode+".png"]["sha256"]
matrix = json.loads((HERE / "canonical-matrix.json").read_text())
assert len(matrix) == 4 and all(not row["environment_diagnostics"] for row in matrix)
assert "2 passed" in (HERE / "backend-canonical-final.log").read_text()
engine = Path("C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe")
library = ROOT / "game/platform/track_geometry/bmt_track_geometry.windows.x86_64.41dbd9ca28a1.dll"
report = {
    "task": "Approved creator capacity implementation", "date": "2026-10-23",
    "requirements": {
        "CAP01": "4096 authored objects, shared client/domain admission",
        "CAP02": "4096 expanded tyre stacks, wall cost six",
        "CAP03": "32 m moving tyre render batches, exact original mesh/transforms",
        "CAP04": "Per-object history and unchanged geometry reuse under existing budgets",
        "CAP05": "Filtered ordered spatial hazard queries, exact simulation",
        "CAP06": "1 MiB creator document contract across client/backend/tooling/schema",
        "CAP07": "128 MiB provisional conservative authored prop geometry preflight",
        "R01": "Actual tests, errors and corrections retained", "G01": "Exact native tyre image pairs",
        "Q01": "Scoped Git patch checked and exact readback"},
    "policy": {"authored_objects": 4096, "simulated_tyre_stacks": 4096,
               "wall_stack_cost": 6, "document_bytes": 1048576,
               "prop_estimate_bytes": 134217728, "phone_calibrated": False,
               "small_scene_memory_exemption": False},
    "capacity": capacity, "canonical_matrix": matrix, "regression": regression,
    "backend": {"capacity": "2 passed (actual staged Godot subprocess)",
                "selected_verifier_publication_sqlite": "57 passed, 2 skipped, 15 deselected",
                "ruff": "Four changed backend files pass",
                "canonical_stage_inputs": 86,
                "test_only_ca_override": "Existing certifi roots in disposable staged project; production error filter untouched"},
    "commands": [
        "powershell -ExecutionPolicy Bypass -Command \"& 'docs/evidence/creator-capacity-implementation-2026-10-23/run.ps1' -Isolated -TestName @('test_tyre_equivalence','test_creator_capacity')\"",
        "powershell -ExecutionPolicy Bypass -Command \"& 'docs/evidence/creator-capacity-implementation-2026-10-23/run.ps1' -Isolated -Graphical -Renderer gl_compatibility\"",
        "powershell -ExecutionPolicy Bypass -Command \"& 'docs/evidence/creator-capacity-implementation-2026-10-23/run.ps1' -Isolated -Graphical -Renderer mobile\"",
        "run.ps1 -TestName @('test_creator','test_hazards','test_speed_bumps','test_editor_t05_t11','test_editor_workflow','test_editor_remaining','test_editor_preparation','test_editor_incremental_objects','test_dynamic_prop_work','test_app') (sequential recorded invocations)",
        "run.ps1 -Isolated -TestName @('test_tyre_equivalence','test_compact_rewind') (separate recorded invocations)",
        "run.ps1 -Graphical -Renderer gl_compatibility -TestName @('test_editor_t05_t11')",
        "run.ps1 -Graphical -Renderer mobile -TestName @('test_editor_t05_t11')",
        ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/creator-capacity-implementation-2026-10-23/canonical.py",
        "Selected backend pytest invocation: backend-unit-command.json",
        ".tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/verifier.py backend/bmt_backend/publications.py backend/deploy/stage_verifier.py backend/tests/test_creator_capacity.py",
        "run.ps1 -TestName @('test_script_parse')",
        ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/creator-capacity-implementation-2026-10-23/checkpoint.py",
        ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/creator-capacity-implementation-2026-10-23/report.py"],
    "images": images, "checkpoint": checkpoint,
    "provenance": {"engine": "4.7.2.stable.official.ed1daf0bf", "engine_sha256": digest(engine),
                   "loaded_native_geometry": str(library.relative_to(ROOT)), "native_geometry_sha256": digest(library),
                   "native_library_changed_by_this_task": False,
                   "original_capture_sha256": json.loads((HERE / "before-sha256.json").read_text())},
    "limitations": [
        "Desktop measurements; physical phone PSS, frame rate, thermal/cold/long-session acceptance remain.",
        "128 MiB is a conservative provisional geometry-stream estimate, not total process/GPU memory or device certification.",
        "Large 4096-grass edits still take 141-199 ms in final paired samples, with full-list planning; cold graphical builds take seconds.",
        "Dense overlapping tyre piles can still exceed a physics tick even below 4096 bodies.",
        "Initial full parser attempts encountered concurrent unfinished fixtures. The final 1011-script parser run passes; failed control diagnostics remain retained.",
        "Historical native-v1 test_rewind imports are retired by current project policy; the attempted fixture failed and was interrupted. Current compact rewind passes.",
        "Initial full-app tyre equivalence completed 13200 comparisons but crashed at teardown; final isolated run exits zero.",
        "Raw Windows startup certificate-store diagnostics are retained; final staged canonical subprocess tests have no engine errors.",
        "Matching client/API/worker canonical-source rollout remains; no deployment occurred."],
    "not_performed": ["phone attachment check", "physical device test", "APK build/install",
                      "live backend/account mutation", "social send", "deployment"],
}
report["evidence_sha256"] = {str(p.relative_to(HERE)).replace("\\", "/"): digest(p)
                             for p in HERE.rglob("*") if p.is_file() and p.name != "report.json"
                             and "__pycache__" not in p.parts}
(HERE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"capacity": {k: v["checks"] for k, v in capacity.items()},
                  "canonical": len(matrix), "images": len(images), "checkpoint": bool(checkpoint)}))
