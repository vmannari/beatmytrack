"""Freeze only this design pass and verify its binary patch outside the repository.

Uses retained task-start/at-edit snapshots; never stages or changes the Git index.
Run after report.json and the scoped root-document entries are complete.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path):
    return path.relative_to(ROOT).as_posix()


def run(*args, cwd):
    return subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def main():
    runtime = ["electric_coachwork.gd"]
    fixtures = []
    helpers = ["test_electric_convex_hood.gd"]
    paths = [ROOT / "game/vehicle" / n for n in runtime]
    paths += [ROOT / "game/tests" / n for n in fixtures + helpers]
    paths += [ROOT / "game/tests" / (n + ".uid") for n in helpers]
    paths += list((ROOT / "game/assets/vehicles/electric_coachwork_v13").glob("*"))
    paths += [ROOT / f"game/assets/vehicles/racing_simple_v1/electric_shadow_{i}.res" for i in range(5)]
    paths += [ROOT / "game/assets/vehicles/racing_simple_v1/manifest.json"]
    paths += [ROOT / n for n in ["game/assets/menu/electric_illustration_v1.png", "game/assets/news/vehicles/electric.png", "game/assets/menu/header_cars_v1/electric.png", "game/assets/garage/previews_v1/electric.png", "game/assets/garage/previews_v1/provenance.json", "game/assets/garage/cars_v1/electric.scn"]]
    paths += list((ROOT / "game/assets/liveries/previews_v2/electric").glob("*.png"))
    # Import descriptors did not change; new UID sidecars above are included.
    paths += [ROOT / "docs/ELECTRIC_CONVEX_HOOD_2026_10_27.md", ROOT / "AGENTS.md", ROOT / "DEVELOPMENT_STATUS.md"]
    # Retain the evidence next to this independent checkpoint. A compact runtime
    # patch avoids embedding hundreds of before/draft PNGs and old source copies.
    for n in ["report.json", "before-after.html", "commands.json", "build_checkpoint.py", "finalize_report.py", "source-comparison.json", "asset-verification.json", "derivative-commands.json", "refresh_derivatives.py", "board-validation.json"]:
        paths.append(EVIDENCE / n)
    selected = sorted(set(p for p in paths if p.is_file()))
    assert len(selected) > 900
    excluded = {"game/vehicle/car_visual.gd", "game/vehicle/vehicle_simulation.gd", "game/resources/cars/electric.tres"}
    assert excluded.isdisjoint(relative(p) for p in selected)
    # Root docs use at-edit contexts, preserving concurrent existing entries.
    def baseline(p):
        n = relative(p)
        for directory in ["before-docs", "before-at-final-integration", "before"]:
            candidate = EVIDENCE / directory / n
            if candidate.is_file():
                return candidate
        return None

    index_before = run("git", "diff", "--cached", "--binary", cwd=ROOT)
    assert index_before.returncode == 0
    with tempfile.TemporaryDirectory(prefix="bmt-edp-checkpoint-") as temporary:
        work = Path(temporary).resolve()
        # TemporaryDirectory's eventual recursive cleanup is constrained here.
        assert work.parent == Path(tempfile.gettempdir()).resolve()
        assert work.name.startswith("bmt-edp-checkpoint-")
        before, after, applied = [work / n for n in ["before", "after", "applied"]]
        for folder in [before, after, applied]:
            folder.mkdir()
        changed = []
        for p in selected:
            n = relative(p)
            old = baseline(p)
            final = EVIDENCE / "after-docs" / n if n in ["AGENTS.md", "DEVELOPMENT_STATUS.md"] else p
            if old is not None and old.read_bytes() == final.read_bytes():
                continue
            for tree, source in [(before, old), (after, final), (applied, old)]:
                if source is not None:
                    target = tree / n
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)
            changed.append({"path": n, "before_sha256": sha(old) if old else None, "after_sha256": sha(final)})
        diff = run("git", "-c", "core.autocrlf=false", "diff", "--no-index", "--binary", "--", "before", "after", cwd=work)
        assert diff.returncode == 1, diff.stderr.decode(errors="replace")
        lines = []
        for line in diff.stdout.splitlines(keepends=True):
            if line.startswith((b"diff --git ", b"--- ", b"+++ ")):
                for prefix in [b"a/before/", b"a/after/", b"b/before/", b"b/after/"]:
                    line = line.replace(prefix, prefix[:2])
            lines.append(line)
        patch = b"".join(lines)
        patch_path = EVIDENCE / "task-only.patch"
        patch_path.write_bytes(patch)
        checked = run("git", "-c", "core.autocrlf=false", "apply", "--check", str(patch_path), cwd=applied)
        assert checked.returncode == 0, checked.stderr.decode(errors="replace")
        result = run("git", "-c", "core.autocrlf=false", "apply", str(patch_path), cwd=applied)
        assert result.returncode == 0, result.stderr.decode(errors="replace")
        for item in changed:
            assert sha(applied / item["path"]) == item["after_sha256"], item["path"]
        index_after = run("git", "diff", "--cached", "--binary", cwd=ROOT)
        assert index_after.returncode == 0 and index_before.stdout == index_after.stdout
        record = {"patch": "task-only.patch", "patch_sha256": sha(patch_path), "patch_bytes": len(patch), "changed_files": len(changed), "git_apply_check": 0, "git_apply": 0, "byte_exact_files": len(changed), "shared_index_unchanged": True, "staged_committed_reset": False, "evidence_note": "Native before/after views, original snapshots and intermediate failures remain adjacent to the patch; they are inventoried in evidence-hashes.json and not embedded as binary patch additions.", "files": changed}
        (EVIDENCE / "checkpoint.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    inventory = {p.relative_to(EVIDENCE).as_posix(): sha(p) for p in sorted(EVIDENCE.rglob("*")) if p.is_file() and p.name != "evidence-hashes.json" and "__pycache__" not in p.parts}
    (EVIDENCE / "evidence-hashes.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in record.items() if k != "files"}))


if __name__ == "__main__":
    main()
