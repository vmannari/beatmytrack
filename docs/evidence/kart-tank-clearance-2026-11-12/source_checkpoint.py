"""Create and byte-verify a task-only patch using an owned, separate Git index."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
CONTROL = ROOT / "build/kart-tank-clearance-2026-11-12/source-checkpoint-qualified"
FILES = [
    "game/vehicle/kart_model.gd", "game/tests/test_kart_tank_clearance.gd",
    "game/tests/review_kart_tank_clearance.gd", "game/tests/bake_kart_tank_geometry.gd",
    "scripts/run_kart_tank_clearance.py", "scripts/rebuild_kart_tank_clearance.py",
    "scripts/finish_kart_tank_refresh.py",
]
FILES += [p + ".uid" for p in FILES if p.endswith(".gd") and (ROOT / (p + ".uid")).exists()
          and p != "game/vehicle/kart_model.gd"]



def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


def git(*args, cwd=CONTROL):
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def main():
    assert not CONTROL.exists(), "Checkpoint already exists; preserve it"
    CONTROL.mkdir(parents=True)
    main_index = digest(ROOT / ".git/index")
    git("init", "-q")
    git("config", "core.autocrlf", "false")
    git("config", "core.whitespace", "cr-at-eol")
    before = {}
    after = {}
    for name in FILES:
        source = OUT / "before" / name
        target = CONTROL / name
        target.parent.mkdir(parents=True, exist_ok=True)
        before[name] = digest(source)
        after[name] = digest(ROOT / name)
        if source.exists():
            shutil.copy2(source, target)
            git("add", "--", name)
    for name in FILES:
        shutil.copy2(ROOT / name, CONTROL / name)
        if before[name] is None:
            git("add", "--intent-to-add", "--", name)
    patch = OUT / "source-only.patch"
    patch.write_bytes(git("diff", "--binary", "--no-ext-diff").stdout)
    whitespace = subprocess.run(["git", "diff", "--check"], cwd=CONTROL, capture_output=True, text=True)
    git("apply", "--check", "--reverse", str(patch), cwd=ROOT)
    git("apply", "--reverse", str(patch))
    assert all(digest(CONTROL / name) == before[name] for name in FILES), "Reverse is not byte exact"
    git("apply", str(patch))
    assert all(digest(CONTROL / name) == after[name] for name in FILES), "Forward is not byte exact"
    assert digest(ROOT / ".git/index") == main_index, "Main index changed"
    original = json.loads((OUT / "before-hashes.json").read_text())
    controls = {name: digest(ROOT / name) == value for name, value in original.items()
                if name.startswith("game/resources/cars/") or name in ("game/vehicle/kart_steering.gd","game/vehicle/kart_driver.gd")
                or name.endswith("/driver.res") or name.endswith("/helmet_static.res")}
    assert all(controls.values())
    (OUT / "source-checkpoint-receipt.json").write_text(json.dumps({
        "files": len(FILES), "before": before, "after": after, "patch_sha256": digest(patch),
        "main_index_unchanged": True, "forward_and_reverse_byte_exact": True,
        "whitespace_check_exit_code": whitespace.returncode, "whitespace_observations": whitespace.stdout.splitlines(),
        "unchanged_controls": controls,
    }, indent=2))
    print("SOURCE_CHECKPOINT", len(FILES), "files; exact forward/reverse; main index unchanged")


if __name__ == "__main__":
    main()
