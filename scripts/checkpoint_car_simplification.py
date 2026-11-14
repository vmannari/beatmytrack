"""Check an isolated source-only forward/reverse patch without main-index writes."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-simplification-2026-11-13"
BUILD = ROOT / "build/car-simplification-2026-11-13"
modified = ["game/vehicle/car_visual.gd", "game/vehicle/racing_car_models.gd",
            "game/vehicle/car_mesh_lods.gd", "game/vehicle/prepared_asset_dependencies.json"]
added = ["game/vehicle/car_static_reduction.gd", "game/vehicle/compact_seam_strip.gd",
         "game/tests/support/car_static_reduction_bake.gd", "game/tests/bake_car_static_reductions.gd",
         "game/tests/test_car_simplification.gd", "game/tests/test_car_simplification_app.gd",
         "game/tests/test_car_simplification_hover_lod.gd", "game/tests/test_car_simplification_steering.gd",
         "game/tests/capture_car_simplification.gd", "game/tests/measure_car_simplification.gd",
         "scripts/run_car_simplification.py", "scripts/refresh_car_simplification.py",
         "scripts/refresh_car_simplification_identity.ps1", "scripts/import_car_simplification_images.py",
         "scripts/compare_car_simplification.ps1", "scripts/summarise_car_simplification.py",
         "scripts/checkpoint_car_simplification.py", "docs/CAR_SIMPLIFICATION_2026_11_13.md"]
added += [name + ".uid" for name in list(added) if name.endswith(".gd") and (ROOT / (name + ".uid")).exists()]
sha = lambda data: hashlib.sha256(data).hexdigest()
start = json.loads((OUT / "start.json").read_text())
assert sha((ROOT / ".git/index").read_bytes()) == start[".git/index"]
patch = []
records = {}
for name in modified + added:
    after = (ROOT / name).read_bytes()
    before = (OUT / "before" / name).read_bytes() if name in modified else b""
    if name in modified:
        assert sha(before) == start[name], name
    patch.append(f"diff --git a/{name} b/{name}\n")
    if name in added:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(before.decode("utf-8").splitlines(True), after.decode("utf-8").splitlines(True),
                 fromfile="a/" + name if name in modified else "/dev/null", tofile="b/" + name))
    records[name] = {"before_sha256": sha(before) if name in modified else None, "sha256": sha(after)}
patch_path = OUT / "source-only.patch"
patch_path.write_bytes("".join(patch).encode("utf-8"))
command = ["git", "-c", f"safe.directory={ROOT}", "apply", "--check", "--reverse", str(patch_path)]
result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
assert result.returncode == 0, result.stderr
scratch = Path(tempfile.mkdtemp(prefix="source-roundtrip-", dir=BUILD)).resolve()
assert scratch.is_relative_to(BUILD.resolve())
try:
    subprocess.run(["git", "init", "--quiet", str(scratch)], check=True, capture_output=True)
    for name in modified:
        target = scratch / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((OUT / "before" / name).read_bytes())
    for reverse in [False, True]:
        command = ["git", "-c", "core.autocrlf=false", "-c",
                   "core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol",
                   "apply", "--whitespace=error"]
        if reverse:
            command += ["--reverse"]
        command += [str(patch_path)]
        result = subprocess.run(command, cwd=scratch, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        for name in modified + added:
            target = scratch / name
            if reverse and name in added:
                assert not target.exists(), name
            else:
                expected = (OUT / "before" / name).read_bytes() if reverse else (ROOT / name).read_bytes()
                assert target.read_bytes() == expected, name
finally:
    assert scratch.is_relative_to(BUILD.resolve())
    shutil.rmtree(scratch)
assert sha((ROOT / ".git/index").read_bytes()) == start[".git/index"]
receipt = {"modified_files_with_independent_baselines": len(modified), "added_source_and_uid_files": len(added),
           "forward_byte_exact": True, "reverse_byte_exact": True, "whitespace_check": "passed",
           "main_index_exact": True, "patch_sha256": sha(patch_path.read_bytes()), "files": records,
           "scope": "Authored source only; generated native assets, images and concurrent Challenger edits excluded."}
(OUT / "source-checkpoint.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
print(json.dumps({key: receipt[key] for key in ["modified_files_with_independent_baselines", "added_source_and_uid_files",
                 "forward_byte_exact", "reverse_byte_exact", "whitespace_check", "main_index_exact"]}))
