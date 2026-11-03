"""Round-trip a task-only binary Git patch in a newly owned temporary repository."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

def baseline(name):
    scoped = OUT / "checkpoint-base" / name
    return scoped if scoped.is_file() else OUT / "before" / name

def main():
    root_index_before = digest(ROOT / ".git/index")
    previous = json.loads((OUT / "baseline-paths.json").read_text())
    # dev.ps1 regenerates the shared build identity. Its unrelated identities
    # are not part of this patch; regenerate it with dev.ps1 after applying.
    excluded = {"game/core/build_identity.gd", "game/vehicle/modular_car_kits.gd", "game/ui/garage_customisation_camera.gd", "game/ui/garage_part_indicator.gd", "game/tests/test_forklift_garage.gd", "backend/bmt_backend/vehicle_appearance_catalog.json"}
    candidates = set(previous) - excluded
    candidates.update(p.relative_to(ROOT).as_posix() for p in (ROOT / "game/assets/vehicles/modular_kits_v1/forklift").rglob("*.scn"))
    candidates.update([
        'game/vehicle/forklift_kit_surface.gd',
        'game/tests/test_forklift_kit_construction.gd',
        'game/tests/capture_forklift_kit_refinement.gd',
        'game/tests/probe_forklift_kit_seams.gd',
        'scripts/run_forklift_refinement.ps1',
        'docs/FORKLIFT_KIT_REFINEMENT_2026_11_02.md',
        'docs/evidence/forklift-kit-refinement-2026-11-02/before/game/vehicle/forklift_model.gd',
        'docs/evidence/forklift-kit-refinement-2026-11-02/before/game/vehicle/forklift_kits.gd',
    ])
    changed = sorted(name for name in candidates if digest(baseline(name)) != digest(ROOT / name))
    work = ROOT / "tmp/forklift-kit-refinement-checkpoint"
    # Never reuse or clear an existing directory.
    work.mkdir(parents=True, exist_ok=False)
    def git(*args):
        result = subprocess.run(["git", "-c", "core.autocrlf=false", *args], cwd=work, capture_output=True, check=True)
        return result.stdout
    git("init", "-q")
    for name in changed:
        source = baseline(name)
        if source.is_file():
            target = work / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    git("add", ".")
    git("-c", "user.name=Codex", "-c", "user.email=codex@local.invalid", "commit", "-qm", "Forklift kit refinement task-start baseline")
    for name in changed:
        source = ROOT / name
        target = work / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_file(): shutil.copyfile(source, target)
        elif target.exists(): target.unlink()
    git("add", ".")
    patch = git("diff", "--cached", "--binary", "HEAD")
    (OUT / "task.patch").write_bytes(patch)
    # Exercise both applications and compare every path byte-for-byte.
    git("apply", "--reverse", "--check", str(OUT / "task.patch"))
    git("apply", "--reverse", str(OUT / "task.patch"))
    assert all(digest(work / n) == digest(baseline(n)) for n in changed)
    git("apply", "--check", str(OUT / "task.patch"))
    git("apply", str(OUT / "task.patch"))
    assert all(digest(work / n) == digest(ROOT / n) for n in changed)
    assert root_index_before == digest(ROOT / ".git/index")
    result = {"files": changed, "patch_bytes": len(patch), "sha256": hashlib.sha256(patch).hexdigest(), "reverse_check": True, "reverse_content": True, "forward_check": True, "forward_content": True, "root_index_written": False, "root_index_sha256": root_index_before, "generated_build_identity_excluded": True, "scoped_baseline": "Retain concurrent documentation and unrelated vehicle catalogue changes"}
    (OUT / "checkpoint.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in result.items() if k != "files"}, indent=2))

if __name__ == "__main__": main()
