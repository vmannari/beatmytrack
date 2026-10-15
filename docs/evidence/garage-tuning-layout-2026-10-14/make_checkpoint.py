"""Isolated layout review; the shared Git branch/index are never written."""
from pathlib import Path
import hashlib
import json
import struct
import subprocess

here = Path(__file__).resolve().parent
root = here.parents[2]
review = root / "build/garage-tuning-layout/checkpoint-repo"
before, after = {}, {}
for name in ["game/ui/garage_page.gd", "game/tests/test_compact_kits.gd"]:
    before[name] = (here / "before" / Path(name).name).read_text(encoding="utf-8-sig")
    after[name] = (root / name).read_text(encoding="utf-8-sig")
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    after[name] = (root / name).read_text(encoding="utf-8-sig")
    if name == "AGENTS.md":
        a = after[name].index("## Tuning workbench matches Painting override")
        b = after[name].index("## ", a + 3)
        before[name] = after[name][:a] + after[name][b:]
    else:
        before[name] = "".join(line for line in after[name].splitlines(keepends=True) if not line.startswith("2026-10-14 GTL01-GTL03/"))
for name in ["game/tests/test_garage_tuning_layout.gd", "docs/GARAGE_TUNING_LAYOUT_2026_10_14.md"]:
    after[name] = (root / name).read_text(encoding="utf-8-sig")
for name in list(after):
    uid = root / (name + ".uid")
    if uid.exists():
        after[name + ".uid"] = uid.read_text()
        if name in before: before[name + ".uid"] = after[name + ".uid"]

markers = ["COMPACT_KITS:", "GARAGE_TUNING_LAYOUT:", "GARAGE_MENU_MOTION: 228", "SCRIPT_PARSE: 733", 'Static function "shoulder()"']
commands = []
for directory in (root / "build/logs").iterdir():
    if not directory.is_dir() or directory.stat().st_ctime < (here / "before").stat().st_ctime: continue
    for log in directory.glob("*.log"):
        text = log.read_text(encoding="utf-8", errors="replace")
        if not any(marker in text for marker in markers): continue
        target = here / "commands" / (directory.name + "__" + log.name)
        target.write_text(text, encoding="utf-8", newline="\n")
        commands.append(target.relative_to(root).as_posix())

review.mkdir(parents=True, exist_ok=False)
def git(*args):
    return subprocess.check_output(["git", "-C", str(review), "-c", "core.autocrlf=false", "-c", "diff.renames=false", "-c", "user.name=Codex", "-c", "user.email=codex@localhost", *args], text=True).strip()
def write(values):
    for name, data in values.items():
        target = review / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(data, encoding="utf-8", newline="\n")
git("init", "--quiet")
write(before)
git("add", "--all")
git("commit", "--quiet", "-m", "Review baseline before Tuning workbench layout")
base = git("rev-parse", "HEAD")
write(after)
proof = {}
for path in here.rglob("*"):
    if not path.is_file() or path.is_relative_to(here / "before") or path.name in ["delivery.json", "task-only.patch"]: continue
    name = path.relative_to(root).as_posix()
    target = review / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(path.read_bytes())
    proof[name] = hashlib.sha256(path.read_bytes()).hexdigest()
git("add", "--all")
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "Match Tuning to Painting with retained car pane and scrolling workbench")
task = git("rev-parse", "HEAD")
patch = subprocess.check_output(["git", "-C", str(review), "diff", "--binary", base, task])
(here / "task-only.patch").write_bytes(patch)
git("apply", "--reverse", "--check", str(here / "task-only.patch"))
assert not git("status", "--porcelain")
captures = {}
for renderer in ["compatibility", "mobile"]:
    for width in [960, 1280, 1600]:
        for section in ["painting", "tuning"]:
            path = here / renderer / (section + "-" + str(width) + ".png")
            captures[path.relative_to(root).as_posix()] = struct.unpack(">II", path.read_bytes()[16:24])
old_assets = json.loads((root / "docs/evidence/compact-kits-quality-2026-10-14/delivery.json").read_text())["assets_sha256"]
assert all(hashlib.sha256((root / name).read_bytes()).hexdigest() == digest for name, digest in old_assets.items())
ledger = {
    "requirements": ["GTL01-GTL03", "CKX01-CKX05", "GCS01-GCS04", "G01", "R01", "Q01"],
    "baseline": base, "task": task, "review_repo": review.relative_to(root).as_posix(),
    "shared_branch_or_index_written_by_this_task": False,
    "source_sha256": {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in after},
    "scoped_source_sha256": {name: hashlib.sha256((review / name).read_bytes()).hexdigest() for name in after},
    "evidence_sha256": proof, "command_receipts": commands, "actual_capture_sizes": captures,
    "checks": {"full_app_per_renderer": 547, "direct_garage_per_renderer": 61, "motion_per_renderer": 228, "scripts": 733, "final_failures": 0},
    "previous_kit_assets_unchanged": len(old_assets),
    "no_phone_apk_backend_deployment_or_canonical_change": True,
    "remaining_acceptance": ["Owner layout review", "Physical-phone visual and touch review"],
}
(here / "delivery.json").write_text(json.dumps(ledger, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({"baseline": base, "task": task, "sources": len(after), "proof": len(proof), "receipts": len(commands), "unchanged_kit_assets": len(old_assets)}))
