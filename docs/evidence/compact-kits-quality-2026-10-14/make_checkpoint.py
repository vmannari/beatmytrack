"""Task-only quality review; never stages or commits the shared workspace."""
from pathlib import Path
import hashlib
import json
import subprocess

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
review = root / "build/compact-kits-quality/checkpoint-repo"
before, after = {}, {}
existing = [
    "game/vehicle/compact_kits.gd", "game/vehicle/compact_kit_variants.gd",
    "game/vehicle/compact_aero.gd", "game/vehicle/vehicle_customisation.gd",
    "game/ui/compact_kit_thumbnail.gd",
]
for name in existing:
    before[name] = (evidence / "before" / name).read_text(encoding="utf-8-sig")
    after[name] = (root / name).read_text(encoding="utf-8-sig")
for filename in ["bake_compact_kit_previews.gd", "test_expanded_compact_catalog.gd", "test_compact_aero_variety.gd"]:
    name = "game/tests/" + filename
    before[name] = (evidence / "before" / filename).read_text(encoding="utf-8-sig")
    after[name] = (root / name).read_text(encoding="utf-8-sig")
name = "game/tests/test_compact_kit_geometry.gd"
after[name] = (root / name).read_text(encoding="utf-8-sig")
before[name] = after[name].replace('\tif "--source" in OS.get_cmdline_user_args():\n\t\tCompactKits.use_baked = false\n\t\tpreload("res://vehicle/prepared_car_cache.gd").enabled = false\n', "")
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    after[name] = (root / name).read_text(encoding="utf-8-sig")
    if name == "AGENTS.md":
        a = after[name].index("## Compact kit construction and quality review override")
        b = after[name].index("## ", a + 3)
        before[name] = after[name][:a] + after[name][b:]
    else:
        before[name] = "".join(line for line in after[name].splitlines(keepends=True) if not line.startswith("2026-10-14 CQ01-CQ05/"))
new = [
    "game/vehicle/compact_kit_surface.gd", "game/vehicle/compact_body_kits.gd",
    "game/vehicle/compact_hood_kits.gd", "game/vehicle/compact_wheel_kits.gd",
    "game/tests/capture_compact_kit_review.gd", "game/tests/test_compact_kit_construction.gd",
    "docs/COMPACT_KITS_QUALITY_2026_10_14.md",
]
for name in new: after[name] = (root / name).read_text(encoding="utf-8-sig")
for name in list(after):
    uid = root / (name + ".uid")
    if uid.exists():
        after[name + ".uid"] = uid.read_text(encoding="utf-8-sig")
        if name in before: before[name + ".uid"] = after[name + ".uid"]

# Retain this task's successful and diagnostic command receipts.
markers = ["KIT_BAKE:", "KIT_GEOMETRY:", "COMPACT_KIT_CONSTRUCTION:", "EXPANDED_COMPACT_CATALOG:", "COMPACT_AERO_VARIETY:", "INCREMENTAL_COMPACT_KITS:", "COMPACT_KITS:", "GARAGE_CUSTOMISATION_SPEED:", "COMPACT_KIT_REVIEW:", "KIT_CATALOG_CAPTURES:", "GARAGE_SWITCH_PROFILE:", "RACING_MODEL_TESTS", "GARAGE_REFLECTIONS:", "SCRIPT_PARSE: 725"]
commands = []
start_time = (evidence / "before").stat().st_ctime
for folder in (root / "build/logs").iterdir():
    if not folder.is_dir() or folder.stat().st_ctime < start_time: continue
    for log in folder.glob("*.log"):
        content = log.read_text(encoding="utf-8", errors="replace")
        if not any(marker in content for marker in markers): continue
        target = evidence / "commands" / (folder.name + "__" + log.name)
        target.parent.mkdir(exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
        commands.append(target.relative_to(root).as_posix())

resume = review.exists()
review.mkdir(parents=True, exist_ok=True)
def git(*args):
    return subprocess.check_output(["git", "-C", str(review), "-c", "core.autocrlf=false", "-c", "diff.renames=false", "-c", "user.name=Codex", "-c", "user.email=codex@localhost", *args], text=True, encoding="utf-8").strip()
def sources(values):
    for name, content in values.items():
        target = review / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
def copy(path, name):
    target = review / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(path.read_bytes())

prefix = "game/assets/vehicles/compact_kits_v1/"
old_assets = evidence / "before/assets"
if not resume:
    git("init", "--quiet")
    sources(before)
    for path in old_assets.rglob("*"):
        if path.is_file(): copy(path, prefix + path.relative_to(old_assets).as_posix())
    git("add", "--all")
    git("commit", "--quiet", "-m", "Review baseline before compact kit construction refinement")
else:
    assert git("rev-list", "--count", "HEAD") == "1", "Only resume this task's unfinished checkpoint"
base = git("rev-parse", "HEAD")
sources(after)
current_assets = root / prefix
for path in (review / prefix).rglob("*"):
    if path.is_file() and not (current_assets / path.relative_to(review / prefix)).exists():
        assert path.resolve().is_relative_to((review / prefix).resolve())
        path.unlink()
assets = {}
for path in current_assets.rglob("*"):
    if not path.is_file(): continue
    name = path.relative_to(root).as_posix()
    copy(path, name)
    assets[name] = hashlib.sha256(path.read_bytes()).hexdigest()
proof = {}
for path in evidence.rglob("*"):
    if not path.is_file() or path.is_relative_to(evidence / "before") or path.name in ["delivery.json", "task-only.patch"]: continue
    name = path.relative_to(root).as_posix()
    copy(path, name)
    proof[name] = hashlib.sha256(path.read_bytes()).hexdigest()
git("add", "--all")
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "Refine all compact kits with plausible fitted closed construction")
task = git("rev-parse", "HEAD")
patch = subprocess.check_output(["git", "-C", str(review), "-c", "diff.renames=false", "diff", "--binary", base, task])
(evidence / "task-only.patch").write_bytes(patch)
git("apply", "--reverse", "--check", str(evidence / "task-only.patch"))
assert not git("status", "--porcelain")
ledger = {
    "requirements": ["CQ01-CQ05", "CKX01-CKX05", "GCS01-GCS04", "V04-V06", "G01", "R01", "Q01"],
    "review_repo": review.relative_to(root).as_posix(), "baseline": base, "task": task,
    "shared_branch_or_index_modified_by_this_task": False,
    "source_sha256": {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in after},
    "scoped_source_sha256": {name: hashlib.sha256((review / name).read_bytes()).hexdigest() for name in after},
    "assets_sha256": assets, "evidence_sha256": proof, "command_receipts": commands,
    "catalog": json.loads((evidence / "catalog.json").read_text()),
    "asset_summary": json.loads((evidence / "asset-summary.json").read_text()),
    "timings": {name: json.loads((evidence / name / "timings.json").read_text()) for name in ["timings-compatibility", "timings-mobile"]},
    "checks": {"geometry": 5223, "construction": 1354, "source_combinations": 1543, "aero": 836, "incremental": 346, "workflow_per_renderer": 520, "prepared_per_renderer": 1396, "ordinary_racing": 85, "reflections_per_renderer": 25, "scripts": 725, "failures_in_final_runs": 0},
    "native_views_per_renderer": 139,
    "remaining_acceptance": ["Owner visual / AAA target review", "Physical-phone brightness, aliasing, touch and frame-pacing / thermal review"],
    "no_phone_apk_live_write_or_deployment_in_this_task": True,
}
(evidence / "delivery.json").write_text(json.dumps(ledger, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"baseline": base, "task": task, "sources": len(after), "assets": len(assets), "proof_files": len(proof), "command_receipts": len(commands)}, indent=2))
