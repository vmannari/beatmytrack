"""Audit actual results and validate a task-only binary Git patch."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
BEFORE = E / "before"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

def logtext(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")

baseline = read(E / "before-hashes.json")
preserved = {}
for name in ["game/vehicle/electric_car_model.gd", "game/vehicle/car_visual.gd",
             "game/vehicle/vehicle_simulation.gd", "game/resources/cars/electric.tres",
             "game/tests/test_electric_model.gd", "game/tests/test_electric_hood.gd"]:
    assert sha(ROOT / name) == baseline[name], name
    preserved[name] = baseline[name]
assets = ROOT / "game/assets/vehicles/electric_coachwork_v6"
manifest = read(assets / "manifest.json")
assert manifest["source_sha256"] == sha(ROOT / "game/vehicle/electric_coachwork.gd")
assert manifest["model_sha256"] == preserved["game/vehicle/electric_car_model.gd"]
assert {p.name for p in assets.glob("*.res")} == {m["file"] for m in manifest["meshes"]}
assert not (ROOT / "game/assets/vehicles/electric_coachwork_v5").exists()
parts = {m["part"]: m for m in manifest["meshes"]}
reuse = read(E / "resource-reuse.json")
assert len(parts) == 537 and len(reuse["resources"]) == 362
for resource in reuse["resources"]:
    assert sha(assets / parts[resource["part"]]["file"]) == resource["sha256"]
validation = read(E / "validation.json")
assert len(validation) == 16 and all(v["exit"] == 0 for v in validation)
parser = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures", logtext(E / "logs/parser.log"))
assert parser
for name in ["garage-race-compatibility", "garage-race-mobile"]:
    assert "ELECTRIC_UI: 60 checks, 0 failures" in logtext(E / f"logs/{name}.log")
results = {name: read(E / path) for name, path in {
    "shape_before": "before/rounded-front.json", "shape_compatibility": "rounded-front.json",
    "shape_desktop_mobile": "mobile-front/rounded-front.json", "hood_compatibility": "hood/hood.json",
    "hood_desktop_mobile": "mobile-hood/hood.json", "model_compatibility": "model/report.json",
    "model_desktop_mobile": "mobile-model/report.json", "surface": "surface-finish.json",
    "handling": "handling.json", "one_pedal": "one-pedal.json", "news": "news-framing.json",
}.items()}
assert results["shape_before"]["failures"] == 6
for name in ["shape_compatibility", "shape_desktop_mobile", "hood_compatibility", "hood_desktop_mobile", "model_compatibility", "model_desktop_mobile", "surface"]:
    assert results[name]["failures"] == 0
cutoff = (E / "before-hashes.json").stat().st_mtime - 5
for path in (ROOT / "build/logs").glob("*/*.log"):
    if path.stat().st_mtime >= cutoff and any(marker in logtext(path) for marker in ["ELECTRIC_", "ONE_PEDAL"]):
        shutil.copy2(path, E / "logs" / f"{path.parent.name}-{path.name}")

rows = []
for level in ["full", "simple"]:
    for shot in ["head-on", "front", "overhead"]:
        rows.append(f'<h2>{level.title()} — {shot}</h2><div class="pair"><figure><figcaption>Before</figcaption><img src="before/{level}-{shot}.png"></figure><figure><figcaption>After</figcaption><img src="{level}-{shot}.png"></figure></div>')
gallery = '''<!doctype html><html lang="en"><meta charset="utf-8"><title>Electric whole-front rounding</title>
<style>body{margin:32px;background:#172129;color:#edf1f3;font:16px system-ui}h1,h2{font-weight:600}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%}figcaption{padding:8px}a{color:#e9c750}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style>
<h1>Electric whole-front rounding</h1><p>Matched native views of the exact preceding model and the redesigned front. The owner's attached Lucid front photograph guides the new silhouette.</p>
<p>The nose, bumper and wings now curve across the entire front. The lower intake is wider with swept ends; the continuous light follows the bowed surface.</p>
<p><a href="mobile-front/full-head-on.png">Desktop Mobile head-on view</a> · <a href="native/garage-1280.png">Actual Garage</a> · <a href="report.json">Measurements and validation</a></p>'''
(E / "gallery.html").write_text(gallery + "\n".join(rows) + "</html>\n", encoding="utf-8")
report = {
    "date": "2026-10-25", "recorded_utc": datetime.now(timezone.utc).isoformat(),
    "requirements": {"ERF01": "substantially round the complete front silhouette", "ERF02": "integrated hood and rolled front wings",
                     "ERF03": "curved light, tall side curtains and wide swept lower intake", "V01": "matching actual before/after views and surface measurements",
                     "R01": "preserve accepted electric behavior and original regression bounds", "G01": "refresh native art and 49 appearance photos", "Q01": "reviewable task-only Git checkpoint"},
    "reference": {"type": "owner_supplied_conversation_image", "dimensions_pixels": [492,352],
                  "description": "Frontal Lucid photograph attached with the owner's request to round the entire front.", "shipping_bitmap": False,
                  "provenance": "Original fictional authored procedural geometry."},
    "results": results, "commands": validation, "parser_scripts": int(parser.group(1)),
    "actual_app_checks": {"compatibility":60,"desktop_mobile":60,"failures":0},
    "preserved_task_start_sha256": preserved,
    "resources": {"old":533,"current":537,"exact_originals":362,"changed_shared":155,"new":20,"retired":16,"proof":"resource-reuse.json"},
    "initial_issues": ["Initial full model was 259 triangles above the retained 170000 limit; reducing redundant hood-surround crosswise subdivisions brings it below the limit and preceding full count.",
                       "Initial new bumper row endpoints did not match side vertical stations; using the existing common stations closes all 134 full/136 simple vertices without weaker assertions.",
                       "Exact previous model produces six expected failures against the same new whole-front shape bounds; all matching before captures remain."],
    "limitations": ["Client reload and owner/device appearance, motion and rendering-cost acceptance remain.",
                    "Desktop Mobile uses PC Vulkan; manual-stepping race-hitch diagnostics are not a frame-pacing measurement.",
                    "No device attachment check or device test, APK, purchase, live mutation, deployment or owner-process restart.",
                    "Concurrent dirty work is preserved. Document snapshots at edit time isolate this task's additions."],
}
write(E / "report.json", report)

checkpoint = Path(tempfile.mkdtemp(prefix="electric-rounded-front-checkpoint-", dir=ROOT / "build"))
a, b = checkpoint / "a", checkpoint / "b"
a.mkdir()
b.mkdir()
def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
for name in ["game/vehicle/electric_coachwork.gd", "game/tests/test_electric_surface_finish.gd", "game/assets/menu/electric_illustration_v1.png"]:
    copy(BEFORE / name, a / name)
    copy(ROOT / name, b / name)
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "README.md", "docs/README.md"]:
    copy(BEFORE / "documents-at-edit" / name, a / name)
    copy(E / "documents-after" / name, b / name)
for name in ["game/tests/test_electric_rounded_front.gd", "game/tests/test_electric_rounded_front.gd.uid", "docs/ELECTRIC_ROUNDED_FRONT_2026_10_25.md"]:
    copy(ROOT / name, b / name)
for source in (BEFORE / "electric_coachwork_v5").iterdir():
    copy(source, a / "game/assets/vehicles/electric_coachwork_v5" / source.name)
for source in assets.iterdir():
    copy(source, b / "game/assets/vehicles/electric_coachwork_v6" / source.name)
for source in (ROOT / "game/assets/liveries/previews_v2/electric").iterdir():
    name = source.relative_to(ROOT)
    if (BEFORE / name).exists(): copy(BEFORE / name, a / name)
    copy(source, b / name)
for source in (ROOT / "game/assets/news/vehicles").glob("electric.png*"):
    name = source.relative_to(ROOT)
    if (BEFORE / name).exists(): copy(BEFORE / name, a / name)
    copy(source, b / name)
diff = subprocess.run(["git", "-c", "core.autocrlf=false", "diff", "--no-index", "--binary", "--find-renames=100%", "a", "b"], cwd=checkpoint, capture_output=True)
assert diff.returncode == 1, diff.stderr.decode(errors="replace")
lines = []
for line in diff.stdout.splitlines(keepends=True):
    if line.startswith((b"diff --git ", b"--- ", b"+++ ")):
        for prefix in [b"a/a/", b"a/b/"]: line = line.replace(prefix,b"a/")
        for prefix in [b"b/a/", b"b/b/"]: line = line.replace(prefix,b"b/")
    elif line.startswith(b"rename from a/"): line = line.replace(b"rename from a/",b"rename from ",1)
    elif line.startswith(b"rename to b/"): line = line.replace(b"rename to b/",b"rename to ",1)
    lines.append(line)
patch = E / "checkpoint.patch"
patch.write_bytes(b"".join(lines))
subprocess.run(["git", "init", "--quiet"], cwd=a, check=True)
for options in [["--check"], []]:
    result = subprocess.run(["git", "-c", "core.autocrlf=false", "apply", *options, str(patch)], cwd=a, capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors="replace")
actual = {str(p.relative_to(a)).replace("\\", "/"):sha(p) for p in a.rglob("*") if p.is_file() and ".git" not in p.relative_to(a).parts}
expected = {str(p.relative_to(b)).replace("\\", "/"):sha(p) for p in b.rglob("*") if p.is_file()}
assert actual == expected
checkpoint_result = {"git_apply_check":"pass","git_apply_and_hash_compare":"pass","final_files":len(expected),
                     "patch_bytes":patch.stat().st_size,"patch_sha256":sha(patch),"shared_index_touched":False,"commit_created":False,"files":expected}
write(E / "checkpoint.json", checkpoint_result)
report["checkpoint"] = {k:v for k,v in checkpoint_result.items() if k != "files"}
write(E / "report.json", report)
print(f"Final report and verified Git patch: {len(expected)} files; {len(parts)} prepared meshes; {parser.group(1)} scripts parsed.")
