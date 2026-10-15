"""Create a scoped review checkpoint; do not touch the shared branch or index."""
from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
review = root / "build/compact-kits-expanded/checkpoint-repo"
baseline, final = {}, {}
source_paths = [
    "game/vehicle/vehicle_customisation.gd", "game/vehicle/compact_kits.gd",
    "game/vehicle/car_visual.gd", "game/vehicle/prepared_car_cache.gd",
    "game/ui/compact_kit_thumbnail.gd", "game/ui/garage_page.gd",
    "game/tests/bake_compact_kit_previews.gd", "game/tests/test_compact_kit_geometry.gd",
    "game/tests/test_compact_kits.gd", "game/tests/test_garage_customisation_speed.gd",
    "game/tests/profile_garage_customisation.gd", "game/tests/capture_compact_kits.gd",
]
status_line = "2026-10-14 CKX01-CKX05/CKT01-CKT06/GCS01-GCS04/V04-V06/G01/R01/Q01: owner refines compact kits to ten choices per hood/aero/rim/body category (Original+9;24 additions), original fitted intake/airfoil/spoke/arch geometry, rolled-fender clearance/flush hardware, scrolling focus/reset visibility and retained actual car/tyres/pivots/paint/condition/camera/reflections.80 native photos/1268 exact prepared meshes;16-photo cache;all10000 combinations per quality max167082/64686 visible triangles. Final geometry5228/source-fit1539/workflow487+487/prepared1398+1398/incremental322+322/captures657+657/racing85/reflections25/parser699 pass. Desktop category4-54ms/install10-60ms Compatibility,26-202ms Mobile;shared host/not phoneFPS. Concurrent cache path issue fixed; owner loading/compiler/account repairs retained/excluded. No phone test/APK/livewrites/deploy/full physics merge regression. Actual options/captures/timings/commands/task-only checkpoint and remaining owner/device AAA acceptance: docs/COMPACT_KITS_EXPANDED_2026_10_14.md."
for name in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    path = root / name
    original = path.read_bytes()
    bom = b"\xef\xbb\xbf" if original.startswith(b"\xef\xbb\xbf") else b""
    body = original[len(bom):]
    newline = b"\r\n" if b"\r\n" in body else b"\n"
    if not body.startswith(b"2026-10-14 CKX01-CKX05/"):
        path.write_bytes(bom + status_line.encode("utf-8") + newline * 2 + body)
for name in source_paths:
    final[name] = (root / name).read_text(encoding="utf-8-sig")
    baseline[name] = (evidence / "before" / name.replace("/", "__")).read_text(encoding="utf-8-sig")

# Concurrent loading work changes constructor/cache APIs. Only the owned roll
# function and tuning block belong to this task's patch; keep other code as base.
name = "game/vehicle/car_visual.gd"
old, current = baseline[name], final[name]
start, stop = old.index("func present_roll("), old.index("\nfunc ", old.index("func present_roll(") + 1)
a, b = current.index("func present_roll("), current.index("\nfunc ", current.index("func present_roll(") + 1)
final[name] = old[:start] + current[a:b] + old[stop:]
name = "game/ui/garage_page.gd"
old, current = baseline[name], final[name]
old = old.replace("var kit_cards: HBoxContainer\n", "var kit_cards: HBoxContainer\nvar kit_scroll: ScrollContainer\n")
a, b = old.index("func _build_tuning("), old.index("func _build_customise(")
c, d = current.index("func _build_tuning("), current.index("func _build_customise(")
final[name] = old[:a] + current[c:d] + old[b:]
name = "game/vehicle/prepared_car_cache.gd"
baseline[name] = final[name].replace("\t_stable_names(car)\n", "")
helper = baseline[name].index("\nstatic func _stable_names(")
baseline[name] = baseline[name][:helper].rstrip() + "\n"

for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    final[name] = (root / name).read_text(encoding="utf-8-sig")
    if name == "AGENTS.md":
        a = final[name].index("## Expanded compact kits override")
        b = final[name].index("\n## ", a)
        baseline[name] = final[name][:a] + final[name][b+1:]
    else:
        baseline[name] = "".join(line for line in final[name].splitlines(keepends=True) if not line.startswith("2026-10-14 CKX01-CKX05/"))
for name in ["game/vehicle/compact_kit_variants.gd", "game/tests/test_expanded_compact_catalog.gd", "game/tests/capture_compact_kit_catalog.gd", "docs/COMPACT_KITS_EXPANDED_2026_10_14.md"]:
    final[name] = (root / name).read_text(encoding="utf-8-sig")
for name in list(final):
    uid = root / (name + ".uid")
    if uid.exists():
        final[name + ".uid"] = uid.read_text(encoding="utf-8-sig")
        if name in baseline: baseline[name + ".uid"] = final[name + ".uid"]

review.mkdir(parents=True, exist_ok=False)
def git(*args):
    return subprocess.check_output(["git", "-C", str(review), "-c", "core.autocrlf=false", "-c", "user.name=Codex", "-c", "user.email=codex@localhost", *args], text=True, encoding="utf-8").strip()
def write_texts(values):
    for name, text in values.items():
        target = review / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8", newline="\n")
def copy_asset(source, name):
    target = review / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(source.read_bytes())

git("init", "--quiet")
write_texts(baseline)
asset_prefix = "game/assets/vehicles/compact_kits_v1/"
for path in (evidence / "before/assets").rglob("*"):
    if path.is_file(): copy_asset(path, asset_prefix + path.relative_to(evidence / "before/assets").as_posix())
git("add", "--all")
git("commit", "--quiet", "-m", "Review baseline before expanding the fitted compact catalog")
base = git("rev-parse", "HEAD")
write_texts(final)
assets = {}
for path in (root / asset_prefix).rglob("*"):
    if not path.is_file(): continue
    name = path.relative_to(root).as_posix()
    copy_asset(path, name)
    assets[name] = hashlib.sha256(path.read_bytes()).hexdigest()
git("add", "--all")
git("diff", "--cached", "--check")
for directory, files in {
    "catalog-compatibility":["hood.png","aero.png","rims.png","body.png"],
    "catalog-mobile":["hood.png","aero.png","rims.png","body.png"],
    "compatibility":["tuning-1280.png"], "mobile":["tuning-1280.png"],
    "close-compatibility":["endurance-front.png","wide-body.png"],
    "close-mobile":["endurance-front.png","wide-body.png"],
    "timings-compatibility":["timings.json","final.png"],
    "timings-mobile":["timings.json","final.png"],
}.items():
    for filename in files:
        path = evidence / directory / filename
        copy_asset(path,path.relative_to(root).as_posix())
copy_asset(evidence / "catalog.json",(evidence / "catalog.json").relative_to(root).as_posix())
git("add", "--all")
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "Refine compact kits and offer ten fitted choices per category")
task = git("rev-parse", "HEAD")
patch = subprocess.check_output(["git", "-C", str(review), "diff", "--binary", base, task])
(evidence / "task-only.patch").write_bytes(patch)
git("apply", "--reverse", "--check", str(evidence / "task-only.patch"))
commands = []
diagnostic_folders = {"TestScript-17440","TestScript-33612","TestScript-14716","TestScript-18836","TestScript-4264","TestScript-16608","TestScript-16376","TestScript-15980","TestScript-17772","CheckScript-34916","CheckScript-16136"}
for folder in (root / "build/logs").glob("*"):
    for log in folder.glob("*.log"):
        text = log.read_text(encoding="utf-8", errors="replace")
        if folder.name not in diagnostic_folders and not any(marker in text for marker in ["KIT_BAKE: 40", "KIT_GEOMETRY: 5228", "EXPANDED_COMPACT_CATALOG:", "COMPACT_KITS: 487", "GARAGE_CUSTOMISATION_SPEED: 1398", "INCREMENTAL_COMPACT_KITS: 322", "KIT_CAPTURES: 657", "KIT_CATALOG_CAPTURES: 4", "GARAGE_SWITCH_PROFILE: complete", "GARAGE_REFLECTIONS:", "RACING_MODEL_TESTS 85", "SCRIPT_PARSE: 699"]): continue
        target = evidence / "commands" / (folder.name + "__" + log.name)
        target.parent.mkdir(exist_ok=True)
        target.write_text(text, encoding="utf-8")
        commands.append(target.relative_to(root).as_posix())
ledger = {
    "requirements": ["CKX01-CKX05", "CKT01-CKT06", "GCS01-GCS04", "V04-V06", "G01", "R01", "Q01"],
    "review_repo": review.relative_to(root).as_posix(), "baseline": base, "task": task,
    "shared_branch_or_index_modified_by_this_task": False,
    "source_sha256": {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in final},
    "scoped_review_sha256": {name: hashlib.sha256((review / name).read_bytes()).hexdigest() for name in final},
    "assets_sha256": assets, "command_receipts": commands,
    "catalog": json.loads((evidence / "catalog.json").read_text()),
    "timings": {name: json.loads((evidence / name / "timings.json").read_text()) for name in ["timings-compatibility", "timings-mobile"]},
    "checks": {"geometry":5228,"source_combination_fit":1539,"workflow_per_renderer":487,"prepared_menu_per_renderer":1398,"incremental_per_renderer":322,"close_capture_per_renderer":657,"ordinary_racing":85,"reflections":25,"scripts":699},
    "remaining_acceptance": ["Owner visual/AAA review", "Physical-phone touch, brightness, aliasing, maximum-kit frame pacing and thermals"],
    "no_phone_test_apk_live_write_or_deployment": True,
}
(evidence / "delivery.json").write_text(json.dumps(ledger, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"baseline":base,"task":task,"assets":len(assets),"sources":len(final),"checkpoint":str(review)},indent=2))
