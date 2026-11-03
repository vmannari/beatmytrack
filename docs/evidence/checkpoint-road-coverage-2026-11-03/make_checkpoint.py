"""Refresh evidence and byte-checked task-only Git patch; never use the main index."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[3]
BUILD = ROOT / "build/checkpoint-road-coverage-2026-11-03"
OUT = Path(__file__).resolve().parent
FILES = [
    "game/race/track_session.gd", "game/race/spline_gate_corridor.gd", "game/race/race_rules.gd",
    "game/race/road_gate_coverage.gd", "game/backend/runner.gd",
    "backend/bmt_backend/contracts.py", "backend/bmt_backend/rivalry.py", "backend/bmt_backend/trajectory_verifier.py",
    "backend/tests/test_hairpin_gate_contract.py", "backend/tests/test_verifier.py", "backend/tests/test_review_reliability.py",
    "game/tests/test_checkpoint_rules.gd", "game/tests/test_bridge_exit_checkpoints.gd",
    "game/tests/test_checkpoint_notice_latency.gd", "game/tests/test_star_checkpoint_consistency.gd",
    "game/tests/test_checkpoint_road_coverage.gd", "game/tests/capture_checkpoint_road_coverage.gd",
    "scripts/run_checkpoint_coverage_checks.py", "scripts/verify_checkpoint_coverage.py",
    "docs/CHECKPOINT_ROAD_COVERAGE_2026_11_03.md", "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(arguments, cwd, codes=(0,)):
    result = subprocess.run(["git", "-c", "core.autocrlf=false", *arguments], cwd=cwd, capture_output=True)
    assert result.returncode in codes, result.stderr.decode(errors="replace")
    return result.stdout


def main():
    for folder in ("gl_compatibility", "mobile"):
        (OUT / folder).mkdir(exist_ok=True)
        for path in (BUILD / folder).glob("*-hairpin.png"):
            shutil.copyfile(path, OUT / folder / path.name)
    for path in (BUILD / "logs").glob("*.log"):
        shutil.copyfile(path, OUT / "logs" / path.name)
    for path in BUILD.glob("*.json"):
        if path.name.endswith("-input.json") or path.name.endswith("-output.json"):
            continue
        shutil.copyfile(path, OUT / path.name)
    sources = []
    with tempfile.TemporaryDirectory(prefix="source-check-", dir=BUILD) as temporary:
        work = Path(temporary).resolve()
        assert work.is_relative_to(BUILD.resolve())
        before, after, verify = work / "before", work / "final", work / "verify"
        for directory in (before, after, verify):
            directory.mkdir()
        for relative in FILES:
            old = BUILD / "before" / relative
            current = (ROOT / relative).read_bytes()
            for directory in (after, OUT / "final"):
                target = directory / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(current)
            previous = old.read_bytes() if old.exists() else None
            if previous is not None:
                for directory in (before, verify, OUT / "before"):
                    target = directory / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(previous)
            sources.append({"path": relative, "before_sha256": sha(previous) if previous is not None else None,
                            "after_sha256": sha(current)})
        patch = git(["diff", "--no-index", "--binary", "--", "before", "final"], work, (0, 1))
        patch = patch.replace(b"a/before/", b"a/").replace(b"b/final/", b"b/")
        patch_path = OUT / "task.patch"
        patch_path.write_bytes(patch)
        git(["init", "--quiet"], verify)
        git(["apply", "--check", str(patch_path)], verify)
        git(["apply", str(patch_path)], verify)
        assert all((verify / row["path"]).read_bytes() == (ROOT / row["path"]).read_bytes() for row in sources)
        git(["apply", "--reverse", "--check", str(patch_path)], verify)
        git(["apply", "--reverse", str(patch_path)], verify)
        for row in sources:
            path = verify / row["path"]
            if row["before_sha256"] is None:
                assert not path.exists()
            else:
                assert sha(path.read_bytes()) == row["before_sha256"]
    with zipfile.ZipFile(OUT / "source-checkpoint.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for row in sources:
            for stage in ("before", "final"):
                path = OUT / stage / row["path"]
                if path.exists():
                    archive.write(path, stage + "/" + row["path"])
    report = {"schema": "bmt-workspace-checkpoint-v1", "files": sources,
              "patch_sha256": sha(patch), "forward_check": True, "forward_bytes_exact": True,
              "reverse_check": True, "reverse_bytes_exact": True, "main_index_written": False,
              "commit_created": False, "deployed": False}
    (OUT / "checkpoint.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"CHECKPOINT_COVERAGE_SOURCE: {len(sources)} files; forward/reverse byte exact; main index untouched")


if __name__ == "__main__":
    main()
