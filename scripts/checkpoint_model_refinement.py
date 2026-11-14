"""Save explicit source snapshots without staging or including concurrent models."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-model-refinement-2026-11-12"
runtime = [
    "compact_front_lamps.gd", "compact_headlamp.gdshader", "compact_coachwork.gd",
    "compact_detail.gd", "forklift_model.gd", "kart_driver.gd", "racing_car_models.gd",
    "kart_model.gd", "hovercraft_sport_drive.gd", "hovercraft_sport_hull.gd",
    "electric_reference_mesh.gd", "electric_reference_body.gd", "electric_reference_details.gd",
]
runtime = ["game/vehicle/" + name for name in runtime]
existing = [
    "game/tests/bake_modular_car_bases.gd", "game/tests/bake_modular_car_kits.gd",
    "game/tests/bake_garage_cars.gd", "game/tests/bake_header_simple_compact.gd",
    "game/tests/support/garage_mesh_lods.gd", "game/tests/bake_kart_driver_polish.gd",
    "game/tests/bake_hovercraft_art.gd", "game/tests/bake_forklift_racing_shadows.gd",
    "game/tests/test_car_wash.gd", "game/tests/check_prepared_assets.gd",
    "scripts/bake_garage_previews.gd", "scripts/check_garage_previews.py",
]
helpers = [
    "game/tests/bake_model_refinement_art.gd", "game/tests/bake_model_refinement_driver.gd",
    "game/tests/bake_model_refinement_shadows.gd", "game/tests/capture_model_refinement.gd",
    "game/tests/check_model_refinement_parse.gd", "game/tests/inspect_model_refinement_driver.gd",
    "game/tests/inspect_model_lod_payload.gd", "game/tests/probe_model_refinement_roundtrip.gd",
    "game/tests/review_model_refinement_metrics.gd", "game/tests/test_model_refinement.gd",
    "game/tests/test_model_refinement_live.gd", "game/tests/support/kart_driver_finish.gd",
    "game/tests/support/car_model_buffers.gd", "game/tests/support/car_refinement_lods.gd",
    "scripts/compare_model_refinement.ps1", "scripts/refresh_model_refinement.py",
    "scripts/refresh_model_refinement_identity.ps1", "scripts/run_model_refinement.py",
    "scripts/snapshot_model_refinement.py", "scripts/summarise_model_refinement.py",
    "scripts/checkpoint_model_refinement.py", "docs/CAR_MODEL_REFINEMENT_2026_11_12.md",
]
files = sorted(set(runtime + existing + helpers))
sha = lambda data: hashlib.sha256(data).hexdigest()
start = json.loads((OUT / "task-start-hashes.json").read_text())
index_before = sha((ROOT / ".git/index").read_bytes())
records = {}
patch = []
with zipfile.ZipFile(OUT / "source-checkpoint.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        data = (ROOT / name).read_bytes()
        archive.writestr(name, data)
        record = {"current_sha256": sha(data), "bytes": len(data)}
        if name in runtime:
            old = (OUT / "before" / name).read_bytes()
            assert sha(old) == start[name], name
            record["baseline_sha256"] = sha(old)
            record["baseline_origin"] = "independently captured task-start bytes"
            # Preserve source line terminators inside hunks.
            patch.append(f"diff --git a/{name} b/{name}\n")
            patch.extend(difflib.unified_diff(old.decode("utf-8").splitlines(True),
                         data.decode("utf-8").splitlines(True),
                         fromfile="a/" + name, tofile="b/" + name))
        else:
            record["baseline_origin"] = "not independently captured; current source snapshot only"
        records[name] = record
with zipfile.ZipFile(OUT / "source-checkpoint.zip") as archive:
    assert archive.testzip() is None
    for name in files:
        assert sha(archive.read(name)) == records[name]["current_sha256"]
patch_path = OUT / "runtime-source-only.patch"
patch_path.write_bytes("".join(patch).encode("utf-8"))
result = subprocess.run(["git", "-c", f"safe.directory={ROOT}", "apply", "--check", "--reverse",
                         str(patch_path)], cwd=ROOT, capture_output=True, text=True)
assert result.returncode == 0, result.stderr
assert sha((ROOT / ".git/index").read_bytes()) == index_before
receipt = {"files": records, "snapshot_count": len(files),
           "runtime_patch_files": len(runtime), "runtime_reverse_check": "passed",
           "archive_roundtrip": "all source snapshots byte-exact", "main_index_unchanged_during_checkpoint": True,
           "main_index_equals_task_start": index_before == start[".git/index"],
           "archive_sha256": sha((OUT / "source-checkpoint.zip").read_bytes()),
           "runtime_patch_sha256": sha(patch_path.read_bytes()),
           "limits": "Runtime patch has independent before bytes but includes any subsequent edits to those files. This is a current source checkpoint, not an isolated task-only diff. Generated assets and Challenger model source are excluded."}
(OUT / "source-checkpoint.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
print(json.dumps({key: receipt[key] for key in ["snapshot_count", "runtime_patch_files",
                 "runtime_reverse_check", "archive_roundtrip", "main_index_unchanged_during_checkpoint",
                 "main_index_equals_task_start"]}))
