"""Scoped aero revision, with actual evidence; shared Git remains untouched."""
from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
review = root / "build/compact-aero-variety/checkpoint-repo"
before, after = {}, {}
existing = [
    "game/vehicle/compact_kits.gd", "game/vehicle/compact_kit_variants.gd",
    "game/vehicle/vehicle_customisation.gd", "game/vehicle/car_visual.gd",
    "game/ui/compact_kit_thumbnail.gd", "game/tests/bake_compact_kit_previews.gd",
    "game/tests/test_expanded_compact_catalog.gd", "game/tests/test_compact_kits.gd",
    "game/tests/test_garage_customisation_speed.gd", "game/tests/capture_compact_kit_catalog.gd",
    "game/tests/profile_garage_customisation.gd",
]
for name in existing:
    before[name] = (evidence / "before" / name.replace("/", "__")).read_text(encoding="utf-8-sig")
    after[name] = (root / name).read_text(encoding="utf-8-sig")

# Keep unrelated loading/constructor changes out of the car's task delta.
name = "game/vehicle/car_visual.gd"
original, current = before[name], after[name]
a, b = original.index("func present_roll("), original.index("\nfunc ", original.index("func present_roll(") + 1)
c, d = current.index("func present_roll("), current.index("\nfunc ", current.index("func present_roll(") + 1)
after[name] = original[:a] + current[c:d] + original[b:]

status_line = "2026-10-14 CAV01-CAV05/CKX01-CKX05/GCS01-GCS04/V04-V06/G01/R01/Q01: owner rejects similar spoilers and requests lower/aft big wings.13 aero choices retaining10 savedIDs+Whale tail/Drag deck/Split wing; varied hatch/roof roots, low rear/twin/curved/split blades, closed beveled rear saddles below glass and machined endplates. Native common side/rear photos preserve16-image cache;43 choices/1244 exact full-simple meshes;all13000 combinations max167082/64686. Geometry5192/source1527/aero834+834/workflow520+520/prepared1380+1380/racing85/reflections25/parser714 pass;39 native views+sheet per renderer. Desktop timings in report;no phoneFPS claim. Endplate footprint and photo clipping corrected with bounds/assertions retained. No phone test/APK/livewrites/deploy/full physics merge regression. Options/real captures/commands/limits/scoped checkpoint and remaining owner/device AAA acceptance: docs/COMPACT_AERO_VARIETY_2026_10_14.md."
for name in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    path = root / name
    data = path.read_bytes()
    bom = b"\xef\xbb\xbf" if data.startswith(b"\xef\xbb\xbf") else b""
    body = data[len(bom):]
    newline = b"\r\n" if b"\r\n" in body else b"\n"
    if not body.startswith(b"2026-10-14 CAV01-CAV05/"):
        path.write_bytes(bom + status_line.encode("utf-8") + newline * 2 + body)
    after[name] = path.read_text(encoding="utf-8-sig")
    before[name] = "".join(line for line in after[name].splitlines(keepends=True) if not line.startswith("2026-10-14 CAV01-CAV05/"))
name = "AGENTS.md"
after[name] = (root / name).read_text(encoding="utf-8-sig")
a = after[name].index("## Compact spoiler silhouette and lower rear wings override")
b = after[name].index("\n## ", a)
before[name] = after[name][:a] + after[name][b+1:]
for name in ["game/vehicle/compact_aero.gd", "game/tests/test_compact_aero_variety.gd", "game/tests/capture_compact_aero_variety.gd", "docs/COMPACT_AERO_VARIETY_2026_10_14.md"]:
    after[name] = (root / name).read_text(encoding="utf-8-sig")
for name in list(after):
    uid = root / (name + ".uid")
    if uid.exists():
        after[name + ".uid"] = uid.read_text(encoding="utf-8-sig")
        if name in before: before[name + ".uid"] = after[name + ".uid"]

review.mkdir(parents=True, exist_ok=False)
def git(*args):
    return subprocess.check_output(["git", "-C", str(review), "-c", "core.autocrlf=false", "-c", "user.name=Codex", "-c", "user.email=codex@localhost", *args], text=True, encoding="utf-8").strip()
def write_sources(values):
    for name, content in values.items():
        target = review / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
def copy_file(path, name):
    target = review / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(path.read_bytes())

prefix = "game/assets/vehicles/compact_kits_v1/"
git("init", "--quiet")
write_sources(before)
for path in (evidence / "before/assets").rglob("*"):
    if path.is_file(): copy_file(path,prefix + path.relative_to(evidence / "before/assets").as_posix())
git("add", "--all")
git("commit", "--quiet", "-m", "Review baseline before compact spoiler silhouette revision")
base = git("rev-parse", "HEAD")
write_sources(after)
assets = {}
current_assets = root / prefix
# Mirror retired generated files only in the isolated review assets directory.
for path in (review / prefix).rglob("*"):
    if path.is_file() and not (current_assets / path.relative_to(review / prefix)).exists():
        assert path.resolve().is_relative_to((review / prefix).resolve())
        path.unlink()
for path in current_assets.rglob("*"):
    if not path.is_file(): continue
    name = path.relative_to(root).as_posix()
    copy_file(path,name)
    assets[name] = hashlib.sha256(path.read_bytes()).hexdigest()
for renderer in ["compatibility", "mobile"]:
    for filename in ["catalog.png", "wing-side.png", "endurance-side.png", "endurance-mount.png", "splitwing-rear.png", "drag-rear.png"]:
        path = evidence / renderer / filename
        copy_file(path,path.relative_to(root).as_posix())
for directory in ["timings-compatibility", "timings-mobile"]:
    for filename in ["timings.json", "final.png"]:
        path = evidence / directory / filename
        copy_file(path,path.relative_to(root).as_posix())
for filename in ["aero-fit.json", "catalog.json"]:
    path = evidence / filename
    copy_file(path,path.relative_to(root).as_posix())
git("add", "--all")
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "Differentiate compact spoilers and add lower aft rear wings")
task = git("rev-parse", "HEAD")
patch = subprocess.check_output(["git", "-C", str(review), "diff", "--binary", base, task])
(evidence / "task-only.patch").write_bytes(patch)
git("apply", "--reverse", "--check", str(evidence / "task-only.patch"))
commands = []
for folder in (root / "build/logs").glob("*"):
    for log in folder.glob("*.log"):
        text = log.read_text(encoding="utf-8", errors="replace")
        markers = ["KIT_BAKE: 13", "COMPACT_AERO_VARIETY:", "AERO_VARIETY_CAPTURES:", "COMPACT_KITS: 520", "GARAGE_CUSTOMISATION_SPEED: 1380", "KIT_GEOMETRY: 5192", "EXPANDED_COMPACT_CATALOG: 1527", "SCRIPT_PARSE: 714"]
        if not any(marker in text for marker in markers): continue
        target = evidence / "commands" / (folder.name + "__" + log.name)
        target.parent.mkdir(exist_ok=True)
        target.write_text(text, encoding="utf-8")
        commands.append(target.relative_to(root).as_posix())
ledger = {
    "requirements":["CAV01-CAV05","CKX01-CKX05","GCS01-GCS04","V04-V06","G01","R01","Q01"],
    "review_repo":review.relative_to(root).as_posix(), "baseline":base, "task":task,
    "shared_branch_or_index_modified_by_this_task":False,
    "source_sha256":{name:hashlib.sha256((root / name).read_bytes()).hexdigest() for name in after},
    "scoped_review_sha256":{name:hashlib.sha256((review / name).read_bytes()).hexdigest() for name in after},
    "assets_sha256":assets, "command_receipts":commands,
    "catalog":json.loads((evidence / "catalog.json").read_text()),
    "aero_fit":json.loads((evidence / "aero-fit.json").read_text()),
    "timings":{name:json.loads((evidence / name / "timings.json").read_text()) for name in ["timings-compatibility","timings-mobile"]},
    "checks":{"geometry":5192,"source_combination":1527,"aero_fit_headless":834,"aero_fit_mobile":834,"workflow_per_renderer":520,"prepared_per_renderer":1380,"ordinary_racing":85,"reflections":25,"scripts":714,"failures_in_final_runs":0},
    "capture_views_per_renderer":39,
    "remaining_acceptance":["Owner visual/silhouette/AAA review","Physical phone brightness, aliasing, touch, driving overhang and frame-pacing/thermal review"],
    "no_phone_apk_live_write_or_deployment_in_this_task":True,
}
(evidence / "delivery.json").write_text(json.dumps(ledger,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"baseline":base,"task":task,"sources":len(after),"assets":len(assets),"review":str(review)},indent=2))
