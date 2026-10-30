"""Record measured results and check a task-only binary patch in an isolated tree."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
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

def logtext(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")

def write(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

baseline = read(E / "before-hashes.json")
invariants = {}
for name in ["game/vehicle/electric_car_model.gd", "game/vehicle/car_visual.gd",
             "game/vehicle/vehicle_simulation.gd", "game/resources/cars/electric.tres",
             "game/tests/test_electric_model.gd"]:
    actual = sha(ROOT / name)
    assert actual == baseline[name], name
    invariants[name] = actual

assets = ROOT / "game/assets/vehicles/electric_coachwork_v5"
manifest = read(assets / "manifest.json")
assert manifest["source_sha256"] == sha(ROOT / "game/vehicle/electric_coachwork.gd")
assert manifest["model_sha256"] == invariants["game/vehicle/electric_car_model.gd"]
assert {p.name for p in assets.glob("*.res")} == {m["file"] for m in manifest["meshes"]}
old_manifest = read(BEFORE / "electric_coachwork_v4/manifest.json")
old = {m["part"]: m for m in old_manifest["meshes"]}
new = {m["part"]: m for m in manifest["meshes"]}
identical = [name for name in old.keys() & new.keys()
             if sha(BEFORE / "electric_coachwork_v4" / old[name]["file"]) == sha(assets / new[name]["file"])]
assert len(identical) == 497
assert len(new) == 533
validation = read(E / "validation.json")
assert len(validation) == 13 and all(v["exit"] == 0 for v in validation)
results = {name: read(E / path) for name, path in {
    "hood_compatibility": "hood.json", "hood_desktop_mobile": "mobile-hood/hood.json",
    "model_compatibility": "model/report.json", "model_desktop_mobile": "mobile-model/report.json",
    "surface": "surface-finish.json", "handling": "handling.json", "one_pedal": "one-pedal.json",
    "news": "news-framing.json",
}.items()}
for key in ["hood_compatibility", "hood_desktop_mobile", "model_compatibility", "model_desktop_mobile", "surface"]:
    assert results[key]["failures"] == 0
assert "SCRIPT_PARSE: 1179 scripts, 0 failures" in logtext(E / "logs/parser.log")
for name in ["garage-race-compatibility", "garage-race-mobile"]:
    assert "ELECTRIC_UI: 60 checks, 0 failures" in logtext(E / f"logs/{name}.log")

# Keep the diagnostic failures, bake receipts and successful baseline launch.
cutoff = (E / "before-hashes.json").stat().st_mtime - 60
for path in (ROOT / "build/logs").glob("*/*.log"):
    if path.stat().st_mtime < cutoff:
        continue
    data = logtext(path)
    if any(marker in data for marker in ["ELECTRIC_", "ONE_PEDAL", "electric_hood", "Cannot find member \"source_code\""]):
        shutil.copy2(path, E / "logs" / f"{path.parent.name}-{path.name}")

rows = []
for level in ["full", "simple"]:
    for shot in ["hood", "nose", "overhead"]:
        rows.append(f'<h2>{level.title()} — {shot}</h2><div class="pair"><figure><figcaption>Before</figcaption><img src="before/{level}-{shot}.png"></figure><figure><figcaption>After</figcaption><img src="{level}-{shot}.png"></figure></div>')
gallery = '''<!doctype html><html lang="en"><meta charset="utf-8"><title>Electric hood — native before / after</title>
<style>body{margin:32px;background:#172129;color:#edf1f3;font:16px system-ui}h1,h2{font-weight:600}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%}figcaption{padding:8px}a{color:#e9c750}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style>
<h1>Electric hood redesign — Lucid reference</h1><p>Matched native Compatibility views of exact task-start and final production geometry. No production camera changes.</p>
<p><a href="lucid-air-reference.webp">Official Lucid Air reference photograph (review only)</a> · <a href="mobile-hood/full-hood.png">Desktop Mobile close-up</a> · <a href="native/garage-1280.png">Actual Garage</a> · <a href="report.json">Measurements and validation</a></p>'''
(E / "gallery.html").write_text(gallery + "\n".join(rows) + "</html>\n", encoding="utf-8")

report = {
    "date": "2026-10-25", "recorded_utc": datetime.now(timezone.utc).isoformat(),
    "requirements": {"EHD01": "Lucid-reference hood shape; owner correction replaces Rivian",
                     "EHD02": "rounded clamshell panel with painted returns and recessed reveal",
                     "V01": "fitted, symmetric actual surfaces in both detail levels and renderers",
                     "R01": "preserve accepted electric behavior and production presentation",
                     "G01": "refresh native catalogue, news and 49 appearance photos", "Q01": "task-only verified Git checkpoint"},
    "reference": {"page": "https://lucidmotors.com/air",
                  "image": "https://images.ctfassets.net/5ky6szwjj7ya/gdK5kHYZJAXzxJnqnqaff/572c41c9051d5be4b6a209728f7d5c89/lucid-motors-lucid-air-desktop-04.webp?q=50",
                  "sha256": sha(E / "lucid-air-reference.webp"), "shipping_asset": False,
                  "provenance": "Original fictional procedural mesh; photograph used for visual reference only."},
    "results": results, "commands": validation, "parser_scripts": 1179,
    "resource_reuse_proof": "resource-reuse.json",
    "preserved_task_start_sha256": invariants,
    "resources": {"old": len(old), "current": len(new), "byte_identical": len(identical),
                  "retired_parts": sorted(old.keys() - new.keys()), "new_parts": sorted(new.keys() - old.keys()),
                  "root": "game/assets/vehicles/electric_coachwork_v5"},
    "initial_issues": [
        "Restricted Godot launch could not open its ordinary user diagnostic log; normal local process permissions resolve it.",
        "Initial return lookup used quantized position keys and omitted the simple return's intermediate row; actual 1e-6 metre distance checks correct the fixture.",
        "Actual between-station left/right triangulation differences violated the original 1e-5 metre symmetry threshold; mirrored diagonals fix the geometry without changing the threshold.",
        "Close-ups showed different nose/hood polygon chords; shared transverse stations and exact authored top points fix the join while retaining the strict 1e-6 metre check.",
        "Baseline capture first used an unsupported script location, then needed an explicitly typed GDScript reference for in-memory reload; both corrected without changing shipping sources.",
        "The public reference download initially failed under restricted network access and succeeded with normal process permissions.",
    ],
    "limits": ["Client reload and owner appearance acceptance remain.",
               "No device attachment check or device test, APK, live mutation, purchase, deployment or owner-process restart.",
               "Desktop Mobile is PC Vulkan validation; manual-stepping race-hitch diagnostics are not a frame-pacing benchmark.",
               "Concurrent dirty workspace changes remain outside the task checkpoint."],
}
write(E / "report.json", report)

# Build a before/after tree solely from saved task baselines and explicit task files.
checkpoint = Path(tempfile.mkdtemp(prefix="electric-lucid-hood-checkpoint-", dir=ROOT / "build"))
a, b = checkpoint / "a", checkpoint / "b"
a.mkdir(parents=True)
b.mkdir()
modified = ["game/vehicle/electric_coachwork.gd", "game/tests/test_electric_surface_finish.gd",
            "AGENTS.md", "DEVELOPMENT_STATUS.md", "README.md", "docs/README.md",
            "game/assets/menu/electric_illustration_v1.png"]
added = ["game/tests/test_electric_hood.gd", "game/tests/test_electric_hood.gd.uid",
         "game/tests/capture_electric_hood_before.gd", "game/tests/capture_electric_hood_before.gd.uid",
         "docs/ELECTRIC_LUCID_HOOD_2026_10_25.md"]

def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

for name in modified:
    copy(BEFORE / name, a / name)
    copy(ROOT / name, b / name)
for name in added:
    copy(ROOT / name, b / name)
for source in (BEFORE / "electric_coachwork_v4").iterdir():
    copy(source, a / "game/assets/vehicles/electric_coachwork_v4" / source.name)
for source in assets.iterdir():
    copy(source, b / "game/assets/vehicles/electric_coachwork_v5" / source.name)
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
patch = b"".join(lines)
patch_path = E / "checkpoint.patch"
patch_path.write_bytes(patch)
subprocess.run(["git", "init", "--quiet"], cwd=a, check=True)
for options in [["--check"], []]:
    command = ["git", "-c", "core.autocrlf=false", "apply", *options, str(patch_path)]
    result = subprocess.run(command, cwd=a, capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors="replace")
actual = {str(p.relative_to(a)).replace("\\", "/"): sha(p) for p in a.rglob("*") if p.is_file() and ".git" not in p.relative_to(a).parts}
expected = {str(p.relative_to(b)).replace("\\", "/"): sha(p) for p in b.rglob("*") if p.is_file()}
assert actual == expected, "Applied checkpoint differs from final task tree"
checkpoint_result = {"git_apply_check": "pass", "git_apply_and_hash_compare": "pass",
                     "final_files": len(expected), "patch_bytes": len(patch), "patch_sha256": sha(patch_path),
                     "shared_index_touched": False, "commit_created": False, "final_sha256": expected}
write(E / "checkpoint.json", checkpoint_result)
report["checkpoint"] = {k: v for k, v in checkpoint_result.items() if k != "final_sha256"}
write(E / "report.json", report)
print(f"Report saved; {len(new)} meshes, {len(identical)} identical; Git patch applied and verified across {len(expected)} final files.")
