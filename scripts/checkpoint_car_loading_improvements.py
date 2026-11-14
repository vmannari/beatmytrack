"""Verify this pass's source delta in a private repository; never stage the main tree."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-loading-improvements-2026-11-13"
BUILD = ROOT / "build/car-loading-improvements-2026-11-13"
MODIFIED = [
    "game/vehicle/car_visual.gd", "game/vehicle/vehicle_models.gd",
    "game/vehicle/modular_car_kits.gd", "game/vehicle/kart_driver.gd",
    "game/tests/support/car_model_buffers.gd", "game/tests/support/car_refinement_lods.gd",
    "game/tests/support/kart_driver_finish.gd", "game/tests/bake_modular_car_bases.gd",
    "game/tests/bake_modular_car_kits.gd", "game/tests/bake_garage_cars.gd",
    "game/tests/test_car_simplification.gd",
]
ADDED = [
    "scripts/run_car_loading_improvements.py", "scripts/refresh_car_loading_improvements.py",
    "scripts/refresh_car_loading_improvements_identity.ps1", "scripts/import_car_loading_images.py",
    "scripts/checkpoint_car_loading_improvements.py", "scripts/summarise_car_loading_improvements.py",
    "game/tests/profile_car_loading_improvements.gd", "game/tests/capture_car_loading_improvements.gd",
    "game/tests/test_car_loading_steering.gd", "game/tests/test_car_loading_driver_split.gd",
    "game/tests/test_car_loading_dependencies.gd", "game/tests/test_car_loading_native_pairs.gd",
    "game/tests/test_car_loading_app.gd", "game/tests/measure_car_loading_assets.gd",
    "game/tests/test_car_loading_wash.gd",
    "game/tests/audit_car_loading_live.gd", "game/tests/bake_kart_driver_split.gd",
    "game/tests/support/kart_driver_split.gd", "game/tests/support/car_mesh_sharing.gd",
    "docs/CAR_LOADING_IMPROVEMENTS_2026_11_13.md",
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def baseline(name):
    merged = OUT / "before-merged" / name
    return (merged if merged.exists() else OUT / "before" / name).read_bytes()


def main():
    added = ADDED + [p + ".uid" for p in ADDED if p.endswith(".gd") and (ROOT / (p + ".uid")).exists()]
    index_before = sha((ROOT / ".git/index").read_bytes())
    patch, records = [], {}
    for name in MODIFIED + added:
        before = baseline(name) if name in MODIFIED else b""
        after = (ROOT / name).read_bytes()
        patch.append(f"diff --git a/{name} b/{name}\n")
        if name in added:
            patch.append("new file mode 100644\n")
        patch.extend(difflib.unified_diff(before.decode("utf-8").splitlines(True),
                     after.decode("utf-8").splitlines(True), fromfile="a/" + name
                     if name in MODIFIED else "/dev/null", tofile="b/" + name))
        records[name] = {"before_sha256": sha(before) if name in MODIFIED else None, "sha256": sha(after)}
    target = OUT / "source-only.patch"
    target.write_bytes("".join(patch).encode("utf-8"))
    checked = subprocess.run(["git", "apply", "--check", "--reverse", str(target)],
                             cwd=ROOT, text=True, capture_output=True)
    assert checked.returncode == 0, checked.stderr
    scratch = Path(tempfile.mkdtemp(prefix="source-roundtrip-", dir=BUILD)).resolve()
    assert scratch.is_relative_to(BUILD.resolve())
    try:
        subprocess.run(["git", "init", "--quiet", str(scratch)], check=True, capture_output=True)
        for name in MODIFIED:
            file = scratch / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(baseline(name))
        for reverse in [False, True]:
            command = ["git", "-c", "core.autocrlf=false", "-c",
                       "core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol",
                       "apply", "--whitespace=error"]
            if reverse:
                command.append("--reverse")
            result = subprocess.run(command + [str(target)], cwd=scratch, text=True, capture_output=True)
            assert result.returncode == 0, result.stderr
            for name in MODIFIED + added:
                file = scratch / name
                if reverse and name in added:
                    assert not file.exists(), name
                else:
                    expected = baseline(name) if reverse else (ROOT / name).read_bytes()
                    assert file.read_bytes() == expected, name
    finally:
        assert scratch.is_relative_to(BUILD.resolve())
        shutil.rmtree(scratch)
    assert sha((ROOT / ".git/index").read_bytes()) == index_before
    receipt = {"modified_sources": len(MODIFIED), "added_sources_and_uids": len(added),
               "forward_byte_exact": True, "reverse_byte_exact": True, "whitespace_clean": True,
               "index_unchanged_during_checkpoint": True, "index_sha256": index_before,
               "merged_baseline": "Kart baseline retains concurrent finish code; the static-child finish call is retained in the composed split block.",
               "files": records, "patch_sha256": sha(target.read_bytes())}
    (OUT / "source-checkpoint.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in receipt.items() if k not in ["files", "merged_baseline"]}))


if __name__ == "__main__":
    main()
