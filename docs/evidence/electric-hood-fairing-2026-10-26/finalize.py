"""Audit actual hood correction evidence and an isolated binary Git patch."""
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
DOC = "docs/ELECTRIC_HOOD_FAIRING_2026_10_26.md"

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding="utf-8-sig"))
def write(p, value): p.write_text(json.dumps(value, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
def copy(a, b):
    b.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(a, b)
def logtext(p):
    data = p.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")

baseline = read(E / "before-hashes.json")
preserved = {}
for name in ["game/vehicle/electric_car_model.gd", "game/vehicle/car_visual.gd", "game/vehicle/electric_glass.gdshader", "game/ui/showroom_studio.gd", "game/tests/test_electric_model.gd", "game/tests/test_electric_hood.gd", "game/tests/test_electric_surface_finish.gd", "game/tests/test_electric_smooth_nose.gd", "game/tests/test_electric_rounded_front.gd", "game/tests/test_electric_quality.gd"]:
    assert sha(ROOT / name) == baseline[name], name
    preserved[name] = baseline[name]
concurrent = {}
for name in ["game/vehicle/vehicle_simulation.gd", "game/resources/cars/electric.tres"]:
    concurrent[name] = {"task_start_sha256": baseline[name], "current_sha256": sha(ROOT / name), "included_in_checkpoint": False, "separate_work": "docs/evidence/electric-consistent-handling-2026-10-26"}
write(E / "concurrent-changes.json", concurrent)
assets = ROOT / "game/assets/vehicles/electric_coachwork_v9"
manifest = read(assets / "manifest.json")
assert manifest["source_sha256"] == sha(ROOT / "game/vehicle/electric_coachwork.gd")
assert manifest["model_sha256"] == preserved["game/vehicle/electric_car_model.gd"]
parts = {m["part"]: m for m in manifest["meshes"]}
assert {p.name for p in assets.glob("*.res")} == {m["file"] for m in parts.values()}
assert not (ROOT / "game/assets/vehicles/electric_coachwork_v8").exists()
reuse = read(E / "resource-reuse.json")
assert len(parts) == reuse["current"] == 622
for item in reuse["resources"]: assert sha(assets / parts[item["part"]]["file"]) == item["sha256"]
validation = read(E / "validation.json")
assert len(validation) == 21 and all(v["exit"] == 0 for v in validation)
parser = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures", logtext(E / "logs/parser.log"))
assert parser
results = {name: read(E / path) for name, path in {
    "rejected_original": "before-native/hood-fairing.json", "fairing_compatibility": "native/hood-fairing.json", "fairing_desktop_mobile": "mobile-fairing/hood-fairing.json", "quality_compatibility": "quality/quality.json", "quality_desktop_mobile": "mobile-quality/quality.json", "model_compatibility": "model/report.json", "model_desktop_mobile": "mobile-model/report.json", "retained_nose": "nose/smooth-nose.json", "retained_nose_desktop_mobile": "mobile-nose/smooth-nose.json", "retained_hood": "hood/hood.json", "retained_hood_desktop_mobile": "mobile-hood/hood.json", "retained_surface": "surface-finish.json", "retained_front": "rounded/rounded-front.json", "handling": "handling.json", "one_pedal": "one-pedal.json", "news": "news-framing.json",
}.items()}
assert results["rejected_original"]["checks"] == 39 and results["rejected_original"]["failures"] == 8
for name, result in results.items():
    if name != "rejected_original": assert result.get("failures", 0) == 0, name
app_checks = {}
for name in ["garage-race-compatibility", "garage-race-mobile"]:
    match = re.search(r"ELECTRIC_UI: (\d+) checks, 0 failures", logtext(E / f"logs/{name}.log"))
    assert match and int(match.group(1))>=60, name
    app_checks[name] = int(match.group(1))
cutoff = (E / "before-hashes.json").stat().st_mtime - 5
for p in (ROOT / "build/logs").glob("*/*.log"):
    if p.stat().st_mtime>=cutoff and any(x in logtext(p) for x in ["ELECTRIC_", "ONE_PEDAL", "test_electric_hood_fairing.gd"]): copy(p, E / "logs" / f"{p.parent.name}-{p.name}")

old_metrics = results["rejected_original"]["metrics"]
new_metrics = results["fairing_compatibility"]["metrics"]
old_angle = max(v["maximum_transverse_angle"] for v in old_metrics.values() if "maximum_transverse_angle" in v)
new_angle = max(v["maximum_transverse_angle"] for v in new_metrics.values() if "maximum_transverse_angle" in v)
counts = results["model_compatibility"]["triangles"]
report = {"date": "2026-10-26", "recorded_utc": datetime.now(timezone.utc).isoformat(),
    "requirements": {"EHF01": "remove the pinched outer hood/wing form in the owner's screenshot", "EHF02": "fair the actual outer body and match its shading tangent", "EHF03": "test the previously missed outer shoulder in both detail levels/renderers", "R01": "retain inward taper, convex nose, construction bounds, rear and behavior", "G01": "refresh native art/news/all 49 appearance photos", "Q01": "verified task-only checkpoint"},
    "results": results, "commands": validation, "parser_scripts": int(parser.group(1)), "actual_app_checks": app_checks,
    "measurements": {"old_maximum_transverse_angle": old_angle, "new_maximum_transverse_angle": new_angle, "full_wing_join": new_metrics["full_wing_join"], "simple_wing_join": new_metrics["simple_wing_join"]},
    "preserved_task_start_sha256": preserved, "concurrent_preserved_changes": concurrent,
    "resources": {k:v for k,v in reuse.items() if k not in ["resources", "comparison", "obsolete_bake_outputs_removed"]},
    "source_sha256": sha(ROOT / "game/vehicle/electric_coachwork.gd"), "focused_test_sha256": sha(ROOT / "game/tests/test_electric_hood_fairing.gd"),
    "triangle_budget": {"unchanged_ceiling":170000,"before_full":168138,"before_simple":65386,"after":counts},
    "cause": "The 32nd-power shoulder blend concentrated the height change beside the lid. Independent longitudinal hood/wing sections disagreed at the outer join; fixed-Y finite differences at the rolled wing's square-root limit additionally produced sqrt(slope), rather than the actual along-wing slope, in its normal. Prior tests covered the lid seam and central sections but missed this outer join.",
    "correction": "A broad shoulder blend follows the wing height at the same longitudinal position, preserves the front tangent and fitted cowl edge, and meets a coherent upper-quarter profile. More transverse samples retain the fair strip. A transported derivative and analytic top limit give the rolled wing its proper shading normal. The upper nose skin reaches the new shared boundary.",
    "initial_issues": ["The first added monotonicity check passed the rejected model; a steep but monotonic crease needs actual transverse angle and outer-join gates, now retained with the failing baseline.", "Widening the blend alone softened the dent but retained the outer tangent mismatch; that intermediate source/captures remain.", "Matching the old lower wing height caused an S turn in the retained x=0.65 profile. A coherent upper-quarter profile fixes it without weakening the original one-degree bound.", "The new upper nose exceeded the old 0.90m skin-row cap; native review caught the opening and its bound was corrected before final validation.", "Outer-join collection initially expected UV=1 on clamped duplicate vertices. It now selects the actual physical top boundary, preserving the one-millimetre/six-degree gates and requiring the populated 40/20 samples."],
    "limitations": ["Reload and owner/device appearance, motion and rendering-cost acceptance remain.", "Desktop Mobile is PC Vulkan. Manual-stepping race-hitch messages are not a frame-pacing measurement.", "No physical-device attachment check/test, APK, purchase, live mutation, deployment or owner-process restart.", "Concurrent electric handling/configuration and Garage work are preserved and excluded; root document snapshots isolate this task's edits."],
}
write(E / "report.json", report)
rows = []
for level in ["full", "simple"]:
    for shot in ["owner-angle", "wing-detail", "front", "top", "side"]:
        rows.append(f'<h2>{level}: {shot}</h2><div class="pair"><figure><figcaption>Before</figcaption><img src="before-native/{level}-{shot}.png"></figure><figure><figcaption>After</figcaption><img src="native/{level}-{shot}.png"></figure></div>')
rows.insert(0,'<h2>Actual Garage environment</h2><div class="pair"><figure><figcaption>Before</figcaption><img src="before-native/garage-owner-angle.png"></figure><figure><figcaption>After</figcaption><img src="native/garage-owner-angle.png"></figure></div>')
(E / "gallery.html").write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><title>Electric hood and wing correction</title><style>body{margin:32px;background:#172129;color:#edf1f3;font:16px system-ui}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%}figcaption{padding:8px}a{color:#e9c750}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style><h1>Electric hood and wing correction</h1><p>The rejected outer shoulder and its correction, using identical native cameras, green paint and light rigs. The taper and convex nose are retained.</p><p><a href="mobile-fairing/full-wing-detail.png">Desktop Mobile close-up</a> | <a href="mobile-fairing/garage-owner-angle.png">Desktop Mobile Garage</a> | <a href="report.json">Actual measurements, commands and limitations</a></p>'''+"\n".join(rows)+"</html>\n",encoding="utf-8")

(ROOT / DOC).write_text(f'''# Electric hood and wing fairing — 2026-10-26

The owner rejects the still-malformed bonnet, showing a pinched strip between the lid seam and front fender. The preceding quality pass retained that geometry; this correction explicitly supersedes its exact-front-resource retention requirement for the affected surfaces. [Matched native comparisons](evidence/electric-hood-fairing-2026-10-26/gallery.html), [actual commands/results](evidence/electric-hood-fairing-2026-10-26/report.json), [task-only Git checkpoint](evidence/electric-hood-fairing-2026-10-26/checkpoint.patch).

| Requirement | Implementation and evidence |
| --- | --- |
| EHF01 | Broad, smoothly joined hood and wing replace the concentrated shoulder drop. The maximum measured transverse angle falls from {old_angle:.3f} to {new_angle:.3f} degrees. |
| EHF02 | Hood height follows the actual longitudinal wing position; a coherent upper-quarter profile preserves the convex nose. Transported side derivatives and the analytic rolled-edge limit correct the remaining outer highlight crease. The upper nose skin closes against the revised hood boundary. |
| EHF03 | New real-mesh transverse and outer-join checks cover both shoulders and both model detail levels, with matched studio and actual Garage views. The exact original fails eight of the same 39 checks; final Compatibility/desktop Mobile both pass 39. |
| R01 | Original hood, nose, body-finish, model and broader quality test sources remain exact. Inward taper, one-degree S-turn gate, seams, symmetry, depth, normal, articulation and unchanged 170000 triangle cap pass. All 183 prepared rear resources remain byte-identical. |
| G01 / Q01 | Catalogue art, news and all 49 appearance photos refreshed/imported. Isolated binary patch passes Git apply checking and an applied-tree hash comparison; the shared index is untouched. |

Only `game/vehicle/electric_coachwork.gd` changes at runtime. Its former 32nd-power blend forced the outer height change into a narrow strip; widening it alone did not remove the separate hood/wing tangent mismatch. The revised common height profile removes that mismatch. At the square-root shoulder limit, fixed-Y numerical derivatives also tilted the side normal by the square root of its longitudinal slope. Following the moving shoulder and using the actual top tangent removes that shading error.

Full/simple outer join normals now differ by at most {new_metrics['full_wing_join']['maximum_angle']:.3f}/{new_metrics['simple_wing_join']['maximum_angle']:.3f} degrees over 40/20 tested points, within the new six-degree bound. Actual boundary interpolation gaps are {new_metrics['full_wing_join']['maximum_gap']*1000:.3f}/{new_metrics['simple_wing_join']['maximum_gap']*1000:.3f}mm, below the one-millimetre bound. The transverse turn limit is 30 degrees, with a separate two-millimetre outward-rise gate. These are new regression gates; no previous invariant is relaxed.

V9 has 622 prepared resources: 541 exact original binaries and 81 changed resources. Full/simple triangles are {counts['full']}/{counts['simple']}, under the unchanged 170000 cap. Extra shoulder samples cost 1503/947 triangles relative to v8. The exact v8 directory is archived and verified before retirement. Rear, glass, mirrors, handles and wheels retain their prepared geometry; assembly, control and production camera sources are unchanged by this task.

Pinned Godot 4.7.2 validation is recorded in [the executable 21-command batch](evidence/electric-hood-fairing-2026-10-26/run_validation.ps1). Fairing39/39, retained quality60/60, model34/34, nose32/32, hood34/34, body finish34, roundness8 and actual App Garage/race{app_checks['garage-race-compatibility']}/{app_checks['garage-race-mobile']} pass in Compatibility/desktop Mobile where applicable. Electric60/one-pedal63, import and parser{parser.group(1)} pass. Initial monotonicity-only false acceptance, subtle blend prototype, retained S-turn failure, temporary upper-row opening and boundary-collection fixture errors remain in the evidence. The final old-source comparison fails eight checks without changing any shipping file in its diagnostic process.

Independent electric handling/configuration changed during this task; exact before/current hashes are preserved in [concurrent-changes.json](evidence/electric-hood-fairing-2026-10-26/concurrent-changes.json) and excluded from the geometry checkpoint. Other concurrent work and historical evidence remain. Reload and owner/device visual, motion and rendering-cost acceptance remain. Desktop Mobile is PC Vulkan; no physical-device attachment check/test, APK, purchase, live mutation, deployment or owner-process restart was performed.
''',encoding="utf-8")

summary = f"EHF01-EHF03/R01/G01/Q01: Owner rejects the retained pinched hood/wing strip. A broad shared upper-quarter profile, front-tangent-preserving fairing and transported rolled-edge normal remove the concentrated drop and outer highlight crease. Actual transverse angle falls{old_angle:.2f}to{new_angle:.2f}deg; outer normals agree within2.143/1.623deg over40/20 points, with0.279/0.859mm gaps. Exact original39checks/8fail retained; fairing39/39, quality60/60, model34/34, nose32/32, hood34/34, surface34, roundness8, App{app_checks['garage-race-compatibility']}/{app_checks['garage-race-mobile']}, electric60/one-pedal63 and parser{parser.group(1)}/import pass. V9 has622 resources with541 exact originals including all183 rear parts; full/simple{counts['full']}/{counts['simple']} retain170000 cap. Catalogue/news/all49 photos refreshed. Original test assertions, assembly/presentation/input/cameras and concurrent electric handling work remain. Prior exact-front retention is superseded only for the affected geometry. Commands, native before/after, hashes and scoped checkpoint: {DOC} and docs/evidence/electric-hood-fairing-2026-10-26/report.json. Reload and owner/device appearance/motion/cost acceptance remain. No attachment/device test, APK, purchase, live mutation, deployment or owner-process restart; concurrent work preserved."
marker = "<!-- ELECTRIC-HOOD-FAIRING-20261026 -->"
block = marker+"\n## Electric hood and wing fairing correction (2026-10-26)\n"+summary+"\n<!-- /ELECTRIC-HOOD-FAIRING-20261026 -->\n\n"
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "README.md", "docs/README.md"]:
    path = ROOT / name
    snap = BEFORE / "documents-at-edit" / name
    if (E / "documents-after" / name).exists(): continue
    if not snap.exists(): copy(path, snap)
    data = snap.read_bytes()
    text = data.decode("utf-8")
    assert marker not in text
    nl = "\r\n" if b"\r\n" in data else "\n"
    if name in ["AGENTS.md", "DEVELOPMENT_STATUS.md"]: text = block.replace("\n",nl)+text
    elif name == "README.md": text = text.replace("# Beat my track"+nl+nl,"# Beat my track"+nl+nl+"The electric car's [hood and wing correction](docs/ELECTRIC_HOOD_FAIRING_2026_10_26.md) removes the pinched outer shoulder, with matched native Garage views and retained taper/nose checks."+nl+nl,1)
    else: text = text.replace("# Documentation index"+nl+nl,"# Documentation index"+nl+nl+"- [Electric hood and wing correction (2026-10-26)](ELECTRIC_HOOD_FAIRING_2026_10_26.md): fair outer shoulder and matched shading; real-mesh regression and Garage comparison."+nl,1)
    path.write_bytes(text.encode("utf-8"))
    copy(path, E / "documents-after" / name)

checkpoint = Path(tempfile.mkdtemp(prefix="electric-hood-fairing-checkpoint-",dir=ROOT / "build"))
a,b = checkpoint / "a",checkpoint / "b"
a.mkdir(); b.mkdir()
for name in ["game/vehicle/electric_coachwork.gd","game/assets/menu/electric_illustration_v1.png"]:
    copy(BEFORE/name,a/name); copy(ROOT/name,b/name)
for name in ["AGENTS.md","DEVELOPMENT_STATUS.md","README.md","docs/README.md"]:
    copy(BEFORE/"documents-at-edit"/name,a/name); copy(E/"documents-after"/name,b/name)
for name in ["game/tests/test_electric_hood_fairing.gd","game/tests/test_electric_hood_fairing.gd.uid",DOC]: copy(ROOT/name,b/name)
for p in (BEFORE/"electric_coachwork_v8").iterdir(): copy(p,a/"game/assets/vehicles/electric_coachwork_v8"/p.name)
for p in assets.iterdir(): copy(p,b/"game/assets/vehicles/electric_coachwork_v9"/p.name)
for p in (ROOT/"game/assets/liveries/previews_v2/electric").iterdir():
    name = p.relative_to(ROOT)
    if (BEFORE/name).exists(): copy(BEFORE/name,a/name)
    copy(p,b/name)
for p in (ROOT/"game/assets/news/vehicles").glob("electric.png*"):
    name = p.relative_to(ROOT)
    if (BEFORE/name).exists(): copy(BEFORE/name,a/name)
    copy(p,b/name)
diff = subprocess.run(["git","-c","core.autocrlf=false","diff","--no-index","--binary","--find-renames=100%","a","b"],cwd=checkpoint,capture_output=True)
assert diff.returncode==1,diff.stderr.decode(errors="replace")
lines=[]
for line in diff.stdout.splitlines(keepends=True):
    if line.startswith((b"diff --git ",b"--- ",b"+++ ")):
        for prefix in [b"a/a/",b"a/b/"]: line=line.replace(prefix,b"a/")
        for prefix in [b"b/a/",b"b/b/"]: line=line.replace(prefix,b"b/")
    elif line.startswith(b"rename from a/"): line=line.replace(b"rename from a/",b"rename from ",1)
    elif line.startswith(b"rename to b/"): line=line.replace(b"rename to b/",b"rename to ",1)
    lines.append(line)
patch=E/"checkpoint.patch"
patch.write_bytes(b"".join(lines))
subprocess.run(["git","init","--quiet"],cwd=a,check=True)
for options in [["--check"],[]]:
    result=subprocess.run(["git","-c","core.autocrlf=false","apply",*options,str(patch)],cwd=a,capture_output=True)
    assert result.returncode==0,result.stderr.decode(errors="replace")
actual={p.relative_to(a).as_posix():sha(p) for p in a.rglob("*") if p.is_file() and ".git" not in p.relative_to(a).parts}
expected={p.relative_to(b).as_posix():sha(p) for p in b.rglob("*") if p.is_file()}
assert actual==expected
proof={"git_apply_check":"pass","git_apply_and_hash_compare":"pass","final_files":len(expected),"patch_bytes":patch.stat().st_size,"patch_sha256":sha(patch),"shared_index_touched":False,"commit_created":False,"files":expected}
write(E/"checkpoint.json",proof)
report["checkpoint"]={k:v for k,v in proof.items() if k!="files"}
write(E/"report.json",report)
print(f"Final report and verified patch: {len(expected)} files; {len(parts)} prepared meshes; parser {parser.group(1)}.")
