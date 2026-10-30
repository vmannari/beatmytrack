"""Record native evidence and verify an isolated, task-only binary Git patch."""
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
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")

def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

def logtext(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")

baseline = read(E / "before-hashes.json")
preserved = {}
for name in ["game/vehicle/car_visual.gd", "game/vehicle/window_reflection.gdshader",
             "game/tests/test_electric_model.gd", "game/tests/test_electric_hood.gd",
             "game/tests/test_electric_rounded_front.gd", "game/tests/test_electric_smooth_nose.gd"]:
    assert sha(ROOT / name) == baseline[name], name
    preserved[name] = baseline[name]
current_physics_receipt = read(ROOT / "docs/evidence/electric-190-2026-10-25/report.json")
concurrent = {}
for name in ["game/vehicle/vehicle_simulation.gd", "game/resources/cars/electric.tres"]:
    current = sha(ROOT / name)
    approved = current_physics_receipt.get("sha256", {}).get(name, current_physics_receipt.get("preserved_sha256", {}).get(name))
    # The current versioned physics/configuration belong to the independent
    # owner-authorized radius/cap task, never to this geometry patch.
    if approved is None:
        assert current in json.dumps(current_physics_receipt), name
    else:
        assert current == approved, name
    concurrent[name] = {"task_start_sha256": baseline[name], "current_sha256": current,
                        "owner_task_receipt": "docs/evidence/electric-190-2026-10-25/report.json",
                        "included_in_checkpoint": False}
write(E / "concurrent-changes.json", concurrent)

assets = ROOT / "game/assets/vehicles/electric_coachwork_v8"
manifest = read(assets / "manifest.json")
assert manifest["source_sha256"] == sha(ROOT / "game/vehicle/electric_coachwork.gd")
assert manifest["model_sha256"] == sha(ROOT / "game/vehicle/electric_car_model.gd")
parts = {m["part"]: m for m in manifest["meshes"]}
assert {p.name for p in assets.glob("*.res")} == {m["file"] for m in parts.values()}
assert not (ROOT / "game/assets/vehicles/electric_coachwork_v7").exists()
reuse = read(E / "resource-reuse.json")
assert len(parts) == reuse["current"] == 622
for resource in reuse["resources"]:
    assert sha(assets / parts[resource["part"]]["file"]) == resource["sha256"]
validation = read(E / "validation.json")
assert len(validation) == 19 and all(v["exit"] == 0 for v in validation)
parser = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures", logtext(E / "logs/parser.log"))
assert parser
for name in ["garage-race-compatibility", "garage-race-mobile"]:
    assert "ELECTRIC_UI: 60 checks, 0 failures" in logtext(E / f"logs/{name}.log")
results = {name: read(E / path) for name, path in {
    "rejected_original": "before-native/quality.json", "quality_compatibility": "native/quality.json",
    "quality_desktop_mobile": "mobile-quality/quality.json", "model_compatibility": "model/report.json",
    "model_desktop_mobile": "mobile-model/report.json", "retained_nose": "nose/smooth-nose.json",
    "retained_nose_desktop_mobile": "mobile-nose/smooth-nose.json", "retained_hood": "hood/hood.json",
    "retained_hood_desktop_mobile": "mobile-hood/hood.json", "retained_surface": "surface-finish.json",
    "retained_front": "rounded/rounded-front.json", "handling": "handling.json",
    "one_pedal": "one-pedal.json", "news": "news-framing.json",
}.items()}
assert results["rejected_original"]["checks"] == 60 and results["rejected_original"]["failures"] == 38
for name, result in results.items():
    if name not in ["rejected_original", "news"]:
        assert result.get("failures", 0) == 0, name
cutoff = (E / "before-hashes.json").stat().st_mtime - 5
for path in (ROOT / "build/logs").glob("*/*.log"):
    if path.stat().st_mtime >= cutoff and any(marker in logtext(path) for marker in ["ELECTRIC_", "ONE_PEDAL", "res://tests/test_electric_quality.gd"]):
        copy(path, E / "logs" / f"{path.parent.name}-{path.name}")

rows = []
for level in ["full", "simple"]:
    for shot in ["rear", "rear-quarter", "tail-detail", "mirror", "wheel", "front-quarter", "side", "roof", "green-rear"]:
        rows.append(f'<h2>{level.title()}: {shot}</h2><div class="pair"><figure><figcaption>Before</figcaption><img src="before-native/{level}-{shot}.png"></figure><figure><figcaption>After</figcaption><img src="native/{level}-{shot}.png"></figure></div>')
(E / "gallery.html").write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><title>Electric model quality pass</title>
<style>body{margin:32px;background:#172129;color:#edf1f3;font:16px system-ui}h1,h2{font-weight:600}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%}figcaption{padding:8px}a{color:#e9c750}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style>
<h1>Electric rear and whole-car quality pass</h1><p>Matched native views of the exact rejected model and the new geometry, with identical cameras, light rig and paint colours.</p>
<p>The rear has a convex body, painted deck lip, slim layered optics, formed plate and swept lower bumper. Fitted glazing, mirrors, handles, dished wheels and closed wheel cavities complete the pass.</p>
<p><a href="mobile-quality/full-rear.png">Desktop Mobile rear</a> | <a href="mobile-quality/full-rear-quarter.png">Desktop Mobile rear quarter</a> | <a href="model/electric-regeneration.png">Regeneration lamps</a> | <a href="native/garage-1280.png">Actual Garage</a> | <a href="report.json">Checks and limitations</a></p>
<p>These desktop checks verify construction and retained behavior; owner/device appearance, motion and rendering-cost acceptance remain.</p>'''+"\n".join(rows)+"</html>\n", encoding="utf-8")
sources = ["game/vehicle/electric_coachwork.gd", "game/vehicle/electric_car_model.gd", "game/vehicle/electric_glass.gdshader", "game/ui/showroom_studio.gd", "game/tests/test_electric_quality.gd", "game/tests/test_electric_surface_finish.gd"]
report = {
    "date": "2026-10-25", "recorded_utc": datetime.now(timezone.utc).isoformat(),
    "requirements": {"EQP01": "sculpt the slab rear into a continuous rounded volume", "EQP02": "layered rear optics, fitted plate and connected aero surfaces", "EQP03": "coherent whole-car glazing, mirrors, handles, wheel detailing and closed wheel wells", "R01": "retain accepted hood/nose, articulation, control and physics behavior", "G01": "refresh native catalogue/news/all 49 appearance photos", "Q01": "task-only Git-checked checkpoint"},
    "reference": {"type": "owner supplied game screenshot and earlier Lucid design direction", "shipping_reference_bitmap": False, "shipping_brand_logo": False},
    "results": results, "commands": validation, "parser_scripts": int(parser.group(1)),
    "actual_app_checks": {"compatibility": 60, "desktop_mobile": 60, "failures": 0},
    "sha256": {name: sha(ROOT / name) for name in sources}, "preserved_task_start_sha256": preserved,
    "concurrent_preserved_changes": concurrent,
    "resources": {k: v for k, v in reuse.items() if k not in ["resources", "obsolete_bake_outputs_removed", "comparison"]},
    "budget": {"unchanged_full_ceiling": 170000, "full_before": 169734, "full_after": 168138, "simple_before": 70506, "simple_after": 65386},
    "fixture_changes": "Surface-ray selection now includes RearLightGuide and RearLens, the replacements for the retired RearLightBar/RearLightReturn. All original depth samples, tolerances and seam checks are retained. New quality checks reject 38/60 cases on the exact task-start model.",
    "initial_issues": ["New capture fixture initially called apply_livery without its required argument and then used top-level colour fields; corrected to the existing livery dictionary contract before matched baseline capture.", "Node names sanitize periods in float suffixes; mirror checks now count the actual two whole shells rather than expecting an unsanitized name.", "Native review found hidden/mirrored plate text, reflective demister artifacts and opposite-side sill visible through the arch. Winding, inset fit, matte traces, closed tubs and inward-facing arch returns correct these; diagnostic picks and intermediate views remain.", "The initial retained surface test omitted the new optical mesh names and reached the pocket back; adding the replacement surfaces preserves the original depth assertions."],
    "limitations": ["A substantial native model quality correction; tests do not certify an overall AAA production standard.", "Client reload and owner/device appearance, motion and rendering-cost acceptance remain.", "Desktop Mobile means PC Vulkan; no physical-device attachment check or test, APK, real purchase, live mutation, deployment or owner-process restart.", "Concurrent owner-authorized physics/cap, kart, UI, language and other work is preserved and excluded from this checkpoint."],
}
write(E / "report.json", report)

doc = ROOT / "docs/ELECTRIC_QUALITY_PASS_2026_10_25.md"
doc.write_text(f'''# Electric rear and whole-car quality pass — 2026-10-25

The owner rejects the basic rear and asks for a much higher overall car quality. This pass replaces the slab-tail presentation and refines the native model as a whole. [Matched before/after gallery](evidence/electric-quality-pass-2026-10-25/gallery.html), [measurements and commands](evidence/electric-quality-pass-2026-10-25/report.json), [Git checkpoint](evidence/electric-quality-pass-2026-10-25/checkpoint.patch).

| Requirement | Result and implementation |
| --- | --- |
| EQP01 | Convex tail wraps into the quarters; actual centre-to-outer bow is 0.08579/0.08652 model metres in full/simple. The small lip is formed in the painted deck rather than a separate bright accent blade. |
| EQP02 | Slim recessed smoked optics have a rounded brake guide, lower guide and end cells. Curved plate lettering/fasteners, camera, subtle parking sensors, swept valance and connected undertray channels replace the blank plate and dangling rectangular fins. |
| EQP03 | Swept mirror shells with recessed curved glass; thinner fitted screen apertures/seals; curved matte demister traces; flush handles; dished forged spokes and shallow hub/fasteners. Closed inner wheel tubs and corrected inward-facing arch-return normals eliminate cross-body views. |
| R01 | All 166 prepared front/hood resources remain exact originals. Existing hood/front/surface invariants and model budget remain. Steering/rolling calipers and one-pedal controls pass their retained tests. Independent electric-11/physics 0.72 work is preserved and excluded. |
| G01 | Native menu artwork, news photo and all 49 electric appearance photos refreshed and imported. |
| Q01 | Isolated binary Git patch checked, applied and byte-compared against its final tree; shared index untouched. |

Runtime scope: `electric_coachwork.gd`, `electric_car_model.gd`, new `electric_glass.gdshader`, and one showroom material-selection condition that recognizes the electric shader. Other cars retain the original glass shader. Opaque analytic glazing adds no scene capture, screen read, transparency pass, light or per-frame script callback. The original Barlow font supplies baked fictional BMT 007 plate lettering; no Lucid name, logo or reference photo ships.

Prepared v8 has 622 resources, including 231 byte-identical originals. The exact v7 directory is archived under evidence before retirement. Full/simple counts fall from 169734/70506 to 168138/65386, below the unchanged 170000 full-model ceiling. Removing buried screen/gasket skins and bulky handle hardware funds the new rear and inner construction.

Validation uses pinned Godot 4.7.2 through `scripts/dev.ps1`. [The executable batch](evidence/electric-quality-pass-2026-10-25/run_validation.ps1) records all 19 successful commands and raw logs. Quality 60/60 and model 34/34 pass in Compatibility/desktop Mobile. Retained smooth nose 32/32, hood 34/34, surface 34 and rounded front 8 pass. Actual Garage/race 60/60, electric 60, one-pedal 63, import and parser {parser.group(1)} pass. Each renderer/detail level exposes all 49 rear lamp samples; all 24 tested inner-wheel sightlines hit their closed tubs. Shared body/end joins match at 134/134 full and 136/136 simple vertices with a maximum 0.0037-degree normal difference.

The exact task-start model is reloaded only in isolated process memory and fails 38 of the same 60 focused checks. Intermediate native views, the original failure, initial fixture mistakes, mirrored/hidden plate, demister and arch-winding diagnostics are retained. The surface fixture adds only the new optic names to its ray-selection set; every original depth/tolerance remains. No original geometry, symmetry, shading, budget or behavior assertion was weakened.

This is a substantial model quality correction, not an overall AAA certification. Reload is needed to see it in an already-running client. Owner/device appearance, motion and rendering-cost acceptance remain. Desktop Mobile is PC Vulkan, not a device test. No device attachment check/test, APK, real purchase, live mutation, deployment or owner-process restart was performed. Concurrent work is preserved; document snapshots isolate this task's edits.
''', encoding="utf-8")

summary = f"EQP01-EQP03/R01/G01/Q01: Replace the flat tail/bright blade with convex coachwork, formed painted lip, slim layered optics, curved lettered plate and swept valance/undertray. Fitted glazing, swept mirrors, flush handles and dished wheels refine the whole car; closed tubs and inward arch-return winding remove cross-body views. Exact original 60-check/38-failure regression retained; native quality60/60, model34/34, nose32/32, hood34/34, surface34, front8, actual Garage-race60/60, electric60/one-pedal63 and parser{parser.group(1)}/import pass. Full/simple168138/65386 triangles retain170000 cap; v8 has622 resources with231 exact originals including all166 front/hood parts. Catalogue/news/all49 photos refreshed. Independent electric-11/physics0.72 and exact control/camera sources remain. Commands, matched views, hashes and scoped Git-checked checkpoint: docs/ELECTRIC_QUALITY_PASS_2026_10_25.md and docs/evidence/electric-quality-pass-2026-10-25/report.json. Reload and owner/device appearance/motion/cost acceptance remain; no AAA certification, attachment/device test, APK, purchase, live mutation, deployment or owner-process restart. Concurrent work preserved."
marker = "<!-- ELECTRIC-QUALITY-PASS-20261025 -->"
block = marker+"\n## Electric rear and whole-car quality pass (2026-10-25)\n"+summary+"\n<!-- /ELECTRIC-QUALITY-PASS-20261025 -->\n\n"
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "README.md", "docs/README.md"]:
    path = ROOT / name
    snap = BEFORE / "documents-at-edit" / name
    if (E / "documents-after" / name).exists():
        continue  # A rerun must not overwrite another task's later root edits.
    if not snap.exists(): copy(path, snap)
    data = snap.read_bytes()
    text = data.decode("utf-8")
    assert marker not in text
    newline = "\r\n" if b"\r\n" in data else "\n"
    if name in ["AGENTS.md", "DEVELOPMENT_STATUS.md"]:
        text = block.replace("\n", newline)+text
    elif name == "README.md":
        head = "The electric car's [rear and whole-car quality pass](docs/ELECTRIC_QUALITY_PASS_2026_10_25.md) adds a sculpted tail, layered lamps, fitted glazing and mirrors, flush handles and closed wheel cavities. Matched native before/after views are linked in the report."
        text = text.replace("# Beat my track"+newline+newline, "# Beat my track"+newline+newline+head+newline+newline, 1)
    else:
        text = text.replace("# Documentation index"+newline+newline, "# Documentation index"+newline+newline+"- [Electric rear and whole-car quality (2026-10-25)](ELECTRIC_QUALITY_PASS_2026_10_25.md): sculpted tail, layered optics and fitted details; matched native comparison and checks."+newline, 1)
    path.write_bytes(text.encode("utf-8"))
    copy(path, E / "documents-after" / name)

checkpoint = Path(tempfile.mkdtemp(prefix="electric-quality-checkpoint-", dir=ROOT / "build"))
a, b = checkpoint / "a", checkpoint / "b"
a.mkdir()
b.mkdir()
for name in ["game/vehicle/electric_coachwork.gd", "game/vehicle/electric_car_model.gd", "game/tests/test_electric_surface_finish.gd", "game/assets/menu/electric_illustration_v1.png"]:
    copy(BEFORE / name, a / name)
    copy(ROOT / name, b / name)
copy(BEFORE / "showroom_studio.gd", a / "game/ui/showroom_studio.gd")
copy(ROOT / "game/ui/showroom_studio.gd", b / "game/ui/showroom_studio.gd")
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "README.md", "docs/README.md"]:
    copy(BEFORE / "documents-at-edit" / name, a / name)
    copy(E / "documents-after" / name, b / name)
for name in ["game/tests/test_electric_quality.gd", "game/tests/test_electric_quality.gd.uid", "game/vehicle/electric_glass.gdshader", "game/vehicle/electric_glass.gdshader.uid", "docs/ELECTRIC_QUALITY_PASS_2026_10_25.md"]:
    copy(ROOT / name, b / name)
for source in (BEFORE / "electric_coachwork_v7").iterdir():
    copy(source, a / "game/assets/vehicles/electric_coachwork_v7" / source.name)
for source in assets.iterdir():
    copy(source, b / "game/assets/vehicles/electric_coachwork_v8" / source.name)
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
        for prefix in [b"a/a/", b"a/b/"]: line = line.replace(prefix, b"a/")
        for prefix in [b"b/a/", b"b/b/"]: line = line.replace(prefix, b"b/")
    elif line.startswith(b"rename from a/"): line = line.replace(b"rename from a/", b"rename from ", 1)
    elif line.startswith(b"rename to b/"): line = line.replace(b"rename to b/", b"rename to ", 1)
    lines.append(line)
patch = E / "checkpoint.patch"
patch.write_bytes(b"".join(lines))
subprocess.run(["git", "init", "--quiet"], cwd=a, check=True)
for options in [["--check"], []]:
    result = subprocess.run(["git", "-c", "core.autocrlf=false", "apply", *options, str(patch)], cwd=a, capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors="replace")
actual = {p.relative_to(a).as_posix(): sha(p) for p in a.rglob("*") if p.is_file() and ".git" not in p.relative_to(a).parts}
expected = {p.relative_to(b).as_posix(): sha(p) for p in b.rglob("*") if p.is_file()}
assert actual == expected
checkpoint_result = {"git_apply_check": "pass", "git_apply_and_hash_compare": "pass", "final_files": len(expected), "patch_bytes": patch.stat().st_size, "patch_sha256": sha(patch), "shared_index_touched": False, "commit_created": False, "files": expected}
write(E / "checkpoint.json", checkpoint_result)
report["checkpoint"] = {k: v for k, v in checkpoint_result.items() if k != "files"}
write(E / "report.json", report)
print(f"Final report and verified Git patch: {len(expected)} files; {len(parts)} prepared meshes; {parser.group(1)} scripts parsed.")
