"""Consolidate this local investigation without changing production or Git state."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[3]
BASE = Path(__file__).resolve().parent


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    reports = {}
    for mode, expected_cases, expected_checks in [
        ("inventory", 290, 852),
        ("gl_compatibility", 48, 85),
        ("mobile", 48, 85),
    ]:
        report = json.loads((BASE / mode / "report.json").read_text())
        assert len(report["rows"]) == expected_cases
        assert report["checks"] == expected_checks and report["failures"] == 0
        if mode != "inventory":
            assert all(x["original_control_metrics"]["max"] == 0 for x in report["rows"])
            for row in report["rows"]:
                stem = f'{row["theme"]}-{row["kind"]}-{row["view"]}'
                for version in ["original", "lod", "firstlod"]:
                    assert (BASE / mode / f"{stem}-{version}.png").is_file()
        reports[mode] = report

    manifest = json.loads((BASE / "source-manifest-final-start.json").read_text())
    current = {path: sha(ROOT / path) for path in manifest}
    changed = [path for path in manifest if current[path] != manifest[path]]
    assert not changed, f"Audited sources changed during final runs: {changed}"
    (BASE / "source-manifest-final-end.json").write_text(json.dumps(current, indent=2) + "\n")

    logs_folder = BASE / "logs"
    logs_folder.mkdir(exist_ok=True)
    logs = []
    for path in (ROOT / "build/logs").glob("TestScript-*/test-script.log"):
        content = path.read_text(encoding="utf-8-sig", errors="replace")
        if "TRACK_ASSET_" not in content and "review_track_asset_simplification_2026_11_07" not in content:
            continue
        target = logs_folder / f"{path.parent.name}.log"
        shutil.copy2(path, target)
        logs.append(target.relative_to(ROOT).as_posix())

    own_files = [
        ROOT / "game/tests/review_track_asset_simplification_2026_11_07.gd",
        ROOT / "game/tests/support/track_asset_lod_review.gd",
        ROOT / "docs/TRACK_ASSET_SIMPLIFICATION_REVIEW_2026_11_07.md",
        BASE / "run_review.ps1",
        BASE / "review_images.ps1",
        Path(__file__).resolve(),
    ]
    for path in list(own_files[:2]):
        uid = path.with_suffix(path.suffix + ".uid")
        if uid.exists():
            own_files.append(uid)
    patch = []
    for path in own_files:
        content = path.read_text(encoding="utf-8")
        assert not any(line.rstrip() != line for line in content.splitlines()), path
        relative = path.relative_to(ROOT).as_posix()
        patch.extend(difflib.unified_diff([], content.splitlines(keepends=True), fromfile="/dev/null", tofile="b/" + relative))
    (BASE / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
    with zipfile.ZipFile(BASE / "task-only-source-checkpoint.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in own_files:
            archive.write(path, path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(BASE / "task-only-source-checkpoint.zip") as archive:
        assert archive.testzip() is None

    inventory = reports["inventory"]["rows"]
    decisions = []
    for theme, kind, decision in [
        ("winter", "ice_compact", "Strong candidate, preserve full near geometry"),
        ("winter", "snow_castle", "Strong racing candidate, protect near tower edges"),
        ("pine", "container", "Strong racing candidate, protect near hardware"),
        ("night_city", "abandoned_warehouse", "Reject generated first level: truss diagonals lost"),
        ("pine", "tree", "Reject generated first level: needle sprays lost"),
        ("desert", "egypt_pyramid", "Reject generated first level: masonry courses lost"),
        ("pine", "tyre_wall", "No automatic reduction; needs separate authored prototype"),
    ]:
        row = next(x for x in inventory if x["theme"] == theme and x["kind"] == kind)
        decisions.append({"theme": theme, "kind": kind, "triangles": row["triangles"], "first_lod_triangles": row["first_lod_triangles"], "decision": decision})
    receipt = {
        "requirements": ["TAS01", "TAS02", "TAS03"],
        "scope": "Investigation and offline prototype only; production models/builders unchanged by this task",
        "engine": reports["inventory"]["engine"],
        "checks": sum(x["checks"] for x in reports.values()),
        "failures": sum(x["failures"] for x in reports.values()),
        "catalogue_combinations": len(inventory),
        "native_cases": 96,
        "native_captures": 288,
        "exact_original_restoration_controls": 96,
        "source_hashes_unchanged_across_final_runs": not changed,
        "frozen_simplifier": "game/tests/support/track_asset_lod_review.gd",
        "decisions": decisions,
        "logs": sorted(logs),
        "commands": [
            "powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-asset-simplification-2026-11-07/run_review.ps1",
            "powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-asset-simplification-2026-11-07/review_images.ps1",
            "python docs/evidence/track-asset-simplification-2026-11-07/finalize_review.py",
            "git apply --check --reverse docs/evidence/track-asset-simplification-2026-11-07/task-only.patch",
        ],
        "task_files": {p.relative_to(ROOT).as_posix(): sha(p) for p in own_files},
        "limits": [
            "Static individual prop views, not full-track population or camera-motion qualification",
            "Warehouse judged under neutral inspection lighting; original dark captures retained",
            "Geometry reductions do not establish FPS, loading, memory or package-size improvements",
            "No device query/test, APK/export/install, owner-save/process change, live/backend operation or deployment",
            "No main-index mutation; concurrent sources and generated build-identity refresh are excluded from task patch",
        ],
    }
    (BASE / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f'{receipt["checks"]} checks / {receipt["failures"]} failures; {len(manifest)} source hashes stable; {len(own_files)} task files checkpointed')


if __name__ == "__main__":
    main()
