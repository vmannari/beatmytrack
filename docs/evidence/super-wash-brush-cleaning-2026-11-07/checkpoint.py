"""Make a scoped source patch and verify it in independent scratch files."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
existing = [
    "game/ui/car_showroom.gd",
    "game/ui/garage_page.gd",
    "game/ui/garage_super_wash.gd",
    "game/tests/test_super_wash.gd",
    "game/tests/test_super_wash_animation.gd",
    "game/assets/garage/previews_v1/provenance.json",
]
new = ["docs/SUPER_WASH_BRUSH_CLEANING_2026_11_07.md"] + [
    (HERE / name).relative_to(ROOT).as_posix()
    for name in ["run.py", "checkpoint.py"]
]
scratch = ROOT / "tmp/super-wash-brush-cleaning-checkpoint"
scratch.mkdir(parents=True, exist_ok=True)
patch = []
hashes = {}
for relative in existing + new:
    current = ROOT / relative
    original = HERE / "before" / relative
    before = original.read_text(encoding="utf-8") if relative in existing else ""
    after = current.read_text(encoding="utf-8")
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    if relative in new:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True), fromfile=f"a/{relative}" if relative in existing else "/dev/null", tofile=f"b/{relative}"))
    copy = scratch / relative
    copy.parent.mkdir(parents=True, exist_ok=True)
    if relative in existing:
        copy.write_bytes(before.encode("utf-8"))
    else:
        copy.unlink(missing_ok=True)
    hashes[relative] = hashlib.sha256(current.read_bytes()).hexdigest()
target = HERE / "task.patch"
target.write_text("".join(patch), encoding="utf-8", newline="\n")
for flags in [["--check"], [], ["--check", "--reverse"], ["--reverse"]]:
    subprocess.run(["git", "apply", *flags, "--directory=tmp/super-wash-brush-cleaning-checkpoint", str(target)], cwd=ROOT, check=True)
    if not flags:
        for relative in existing + new:
            assert (scratch / relative).read_text(encoding="utf-8") == (ROOT / relative).read_text(encoding="utf-8")
for relative in existing:
    assert (scratch / relative).read_text(encoding="utf-8") == (HERE / "before" / relative).read_text(encoding="utf-8")
for relative in new:
    assert not (scratch / relative).exists()
print(f"CHECKPOINT: {len(existing)+len(new)} files; forward/reverse/content checks pass; main index untouched")
(HERE / "checkpoint.json").write_text(json.dumps({"requirements": ["SBC01", "SBC02", "SBCQ01"], "source_sha256": hashes, "patch_sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "forward_reverse_content_check": "pass"}, indent=2)+"\n", encoding="utf-8")
