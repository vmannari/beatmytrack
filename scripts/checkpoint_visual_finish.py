"""Verify the owned source patch in a disposable repository, without staging.

Run only after the visual-finish sources and final report have settled:
    python scripts/checkpoint_visual_finish.py --verify
Baselines are retained exact task-start bytes, not the shared repository HEAD.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/visual-fixes-2026-11-13"
BASELINES = OUT / "source-baselines"
BUILD = ROOT / "build/visual-fixes-2026-11-13"

# Every entry was confirmed by its owning agent. Shared Super Rally changes use
# the identical root/contour task-start snapshot, once, rather than two patches.
MODIFIED = [
    "game/vehicle/compact_finish.gd",
    "game/vehicle/super_rally_model.gd",
    "game/vehicle/electric_glass.gdshader",
    "game/vehicle/window_reflection.gdshader",
    "game/vehicle/forklift_model.gd",
    "game/vehicle/electric_car_model.gd",
    "game/vehicle/prepared_asset_dependencies.json",
    "game/vehicle/kart_driver.gd",
    "game/vehicle/electric_reference_mesh.gd",
    "game/tests/test_challenger_hellcat.gd",
    "game/track/native_track_visual.gd",
    "native/track_geometry/road_geometry.hpp",
]
ADDED = [
    "game/vehicle/kart_driver_cloth.gdshader",
    "game/vehicle/panel_contour.gd",
    "game/vehicle/panel_contour.gdshader",
    "game/vehicle/challenger_panel_contours.gd",
    "game/assets/vehicles/challenger_hellcat_v1/bonnet_contour.json",
    "game/tests/test_kart_material_finish.gd",
    "game/tests/test_vehicle_material_finish.gd",
    "game/tests/test_panel_contours.gd",
    "game/tests/test_join_cap_miters.gd",
    "game/tests/capture_vehicle_finish.gd",
    "scripts/run_visual_finish.py",
    "scripts/refresh_visual_finish.py",
    "scripts/refresh_visual_finish_identity.ps1",
    "scripts/import_visual_finish_images.py",
    "scripts/checkpoint_visual_finish.py",
    "docs/VISUAL_FIXES_3_4_2026_11_13.md",
    "docs/evidence/visual-fixes-2026-11-13/tooling/test_app.gd",
    "docs/evidence/visual-fixes-2026-11-13/tooling/parse_production.gd",
    "docs/evidence/visual-fixes-2026-11-13/tooling/bake_static.gd",
    "docs/evidence/visual-fixes-2026-11-13/tooling/audit_closeout.py",
]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def preserve_concurrent_world_cache(name: str, original: bytes, current: bytes):
    if name != "game/track/native_track_visual.gd":
        return original, []
    old = original.decode("utf-8").splitlines(keepends=True)
    new = current.decode("utf-8").splitlines(keepends=True)
    normalized, changes = [], []
    for kind, a, b, c, d in difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes():
        if kind != "equal" and 100 <= a < 250:
            text = "".join(old[a:b] + new[c:d])
            if "world" not in text or not any(token in text for token in ["world_key", "world_options", "_world_disk_id"]):
                raise RuntimeError("Unreviewed concurrent early track change")
            normalized.extend(new[c:d])
            changes.append({"original_line": a + 1, "before_sha256": sha("".join(old[a:b]).encode()),
                            "after_sha256": sha("".join(new[c:d]).encode())})
        else:
            normalized.extend(old[a:b])
    if len(changes) != 3:
        raise RuntimeError("Concurrent world-cache scope changed; review it before checkpointing")
    return "".join(normalized).encode("utf-8"), changes


def repo_path(base: Path, name: str) -> Path:
    relative = PurePosixPath(name)
    if relative.is_absolute() or ".." in relative.parts or "\\" in name:
        raise RuntimeError(f"Unsafe source path: {name}")
    path = (base / name).resolve()
    if not path.is_relative_to(base.resolve()):
        raise RuntimeError(f"Source path leaves expected directory: {name}")
    return path


def git(command: list[str], cwd: Path) -> str:
    result = subprocess.run(
        ["git", "-c", f"safe.directory={cwd}", "-c", "core.autocrlf=false",
         "-c", "core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol",
         *command], cwd=cwd, capture_output=True, text=True, timeout=60,
    )
    if result.returncode:
        raise RuntimeError(f"git {' '.join(command)} failed:\n{result.stdout}{result.stderr}")
    return result.stdout.strip()


def main_index_hash() -> str | None:
    # rev-parse reads metadata and does not refresh or rewrite the shared index.
    path = Path(git(["rev-parse", "--git-path", "index"], ROOT))
    if not path.is_absolute():
        path = ROOT / path
    return sha(path.read_bytes()) if path.exists() else None


def make_patch(before: dict[str, bytes], after: dict[str, bytes]) -> bytes:
    chunks: list[str] = []
    for name, current in after.items():
        original = before.get(name, b"")
        if name in before and original == current:
            continue
        chunks.append(f"diff --git a/{name} b/{name}\n")
        if name not in before:
            chunks.append("new file mode 100644\n")
        for line in difflib.unified_diff(
            original.decode("utf-8").splitlines(keepends=True),
            current.decode("utf-8").splitlines(keepends=True),
            fromfile="a/" + name if name in before else "/dev/null",
            tofile="b/" + name,
        ):
            chunks.append(line)
            if not line.endswith("\n"):
                chunks.append("\n\\ No newline at end of file\n")
    return "".join(chunks).encode("utf-8")


def check_scratch(scratch: Path, owner: str) -> None:
    resolved = scratch.resolve()
    if (resolved.parent != BUILD.resolve()
            or not resolved.is_relative_to(ROOT.resolve())
            or not resolved.name.startswith("visual-source-roundtrip-")
            or scratch.is_symlink()
            or (resolved / ".checkpoint-owner").read_text(encoding="utf-8") != owner):
        raise RuntimeError(f"Refusing cleanup outside the owned scratch directory: {resolved}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Run after final sources and report are ready")
    args = parser.parse_args()
    if not args.verify:
        parser.error("--verify is required; finish all source edits and the report first")

    start_bytes = (OUT / "materials/start.json").read_bytes()
    start = json.loads(start_bytes)
    manifest_bytes = (BASELINES / "manifest.json").read_bytes()
    manifest = json.loads(manifest_bytes)
    expected_index = start["controls"].get(".git\\index", start["controls"].get(".git/index"))
    if expected_index is None:
        raise RuntimeError("Task-start index hash is missing; baseline is ambiguous")
    index_before = main_index_hash()
    added = list(ADDED)
    # Godot may create identities during the final import. Only identities for
    # the explicitly new source files belong to this source-only checkpoint.
    added.extend(name + ".uid" for name in ADDED
                 if Path(name).suffix in {".gd", ".gdshader"}
                 and repo_path(ROOT, name + ".uid").is_file())
    if len(set(MODIFIED + added)) != len(MODIFIED + added):
        raise RuntimeError("Duplicate or conflicting source ownership")

    before: dict[str, bytes] = {}
    raw_before: dict[str, bytes] = {}
    after: dict[str, bytes] = {}
    records = {}
    concurrent = {}
    for name in MODIFIED + added:
        current = repo_path(ROOT, name).read_bytes()
        after[name] = current
        if name in MODIFIED:
            baseline = manifest["files"].get(name)
            if baseline is None:
                raise RuntimeError(f"Missing independent task-start baseline: {name}")
            original = repo_path(BASELINES, name).read_bytes()
            if sha(original) != baseline["sha256"]:
                raise RuntimeError(f"Changed task-start baseline: {name}")
            if name in start["owned_sources"] and sha(original) != start["owned_sources"][name]:
                raise RuntimeError(f"Root/agent task-start baselines disagree: {name}")
            raw_before[name] = original
            before[name], preserved = preserve_concurrent_world_cache(name, original, current)
            if preserved:
                concurrent[name] = {"task_start_sha256": sha(original), "preserved_changes": preserved}
        records[name] = {
            "before_sha256": sha(before[name]) if name in before else None,
            "sha256": sha(current),
            "changed": name not in before or before[name] != current,
        }
    patch = make_patch(before, after)
    if not patch:
        raise RuntimeError("Source checkpoint is empty")

    BUILD.mkdir(parents=True, exist_ok=True)
    if not BUILD.resolve().is_relative_to(ROOT.resolve()):
        raise RuntimeError("Scratch parent is outside the workspace")
    scratch = Path(tempfile.mkdtemp(prefix="visual-source-roundtrip-", dir=BUILD)).resolve()
    owner = uuid.uuid4().hex
    (scratch / ".checkpoint-owner").write_text(owner, encoding="utf-8")
    try:
        git(["init", "--quiet", str(scratch)], scratch)
        patch_path = scratch / "source-only.patch"
        patch_path.write_bytes(patch)
        for name, data in before.items():
            target = repo_path(scratch, name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        for reverse in [False, True]:
            options = ["--reverse"] if reverse else []
            git(["apply", "--check", "--whitespace=error", *options, str(patch_path)], scratch)
            git(["apply", "--whitespace=error", *options, str(patch_path)], scratch)
            for name, current in after.items():
                target = repo_path(scratch, name)
                if reverse and name not in before:
                    if target.exists():
                        raise RuntimeError(f"Reverse left added file behind: {name}")
                elif target.read_bytes() != (before[name] if reverse else current):
                    raise RuntimeError(f"Byte mismatch after {'reverse' if reverse else 'forward'} apply: {name}")
    finally:
        check_scratch(scratch, owner)
        shutil.rmtree(scratch)

    # Fail on source races; index races are recorded, because other authorized
    # work may update the index and this tool never writes it.
    for name, current in after.items():
        if repo_path(ROOT, name).read_bytes() != current:
            raise RuntimeError(f"Concurrent source change; checkpoint not published: {name}")
    for name, original in raw_before.items():
        if repo_path(BASELINES, name).read_bytes() != original:
            raise RuntimeError(f"Baseline changed during verification: {name}")
    if (BASELINES / "manifest.json").read_bytes() != manifest_bytes or (OUT / "materials/start.json").read_bytes() != start_bytes:
        raise RuntimeError("Baseline manifest changed during verification")
    index_after = main_index_hash()
    receipt = {
        "modified_files_with_independent_baselines": len(before),
        "added_source_and_uid_files": len(added),
        "forward_byte_exact": True,
        "reverse_byte_exact": True,
        "whitespace_check": "passed",
        "source_fence": "unchanged through verification",
        "concurrent_changes_preserved_in_both_directions": concurrent,
        "main_index": {"task_start_sha256": expected_index, "before_sha256": index_before,
                       "after_sha256": index_after, "matches_task_start": index_after == expected_index,
                       "unchanged_during_check": index_before == index_after,
                       "writes_by_checkpoint": False},
        "patch_sha256": sha(patch),
        "baseline_manifest_sha256": sha(manifest_bytes),
        "files": records,
        "scope": "Owned source, derived bonnet outline JSON, tests, scripts and report only. Native mesh binaries, textures, previews, platform binaries, owner state and unrelated concurrent edits excluded.",
    }
    # Publish only the fully checked patch, then its receipt. The previous
    # accepted checkpoint is preserved if any validation above rejects.
    patch_tmp = OUT / "source-only.patch.tmp"
    receipt_tmp = OUT / "source-checkpoint.json.tmp"
    patch_tmp.write_bytes(patch)
    receipt_tmp.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    patch_tmp.replace(OUT / "source-only.patch")
    receipt_tmp.replace(OUT / "source-checkpoint.json")
    print(json.dumps({key: receipt[key] for key in [
        "modified_files_with_independent_baselines", "added_source_and_uid_files",
        "forward_byte_exact", "reverse_byte_exact", "main_index"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
