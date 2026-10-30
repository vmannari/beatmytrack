"""Audit real plan-view seams, native comparisons and a task-only Git patch."""
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
DOC = "docs/ELECTRIC_CLEAN_BONNET_2026_10_26.md"

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding="utf-8-sig"))
def write(p,v): p.write_text(json.dumps(v,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
def copy(a,b):
    b.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(a,b)
def logtext(p):
    data=p.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig",errors="replace")

baseline=read(E/"before-hashes.json")
old_fixture=(BEFORE/"game/tests/test_electric_hood.gd").read_text(encoding="utf-8")
fixture=old_fixture.replace('\t\t\t\tvar expected_uv: Vector2 = COACH.hood_rectangle_uv(edge,uv.x)\n\t\t\t\tif edge == 0: expected_uv = Vector2(0.5+0.5*COACH.front_across(uv.x),0)', '\t\t\t\tvar expected_uv: Vector2 = COACH.hood_surround_outer_uv(edge,uv.x)')
assert fixture==(ROOT/"game/tests/test_electric_hood.gd").read_text(encoding="utf-8")
old_master=(BEFORE/"game/vehicle/electric_coachwork.gd").read_text(encoding="utf-8").split("static func hood_panel_uv(")[0]
new_master=(ROOT/"game/vehicle/electric_coachwork.gd").read_text(encoding="utf-8").split("static func hood_panel_uv(")[0]
assert old_master.replace("electric_coachwork_v9","electric_coachwork_v10")==new_master
preserved={}
for name in ["game/vehicle/electric_car_model.gd","game/vehicle/car_visual.gd","game/vehicle/electric_glass.gdshader","game/ui/showroom_studio.gd","game/tests/test_electric_model.gd","game/tests/test_electric_surface_finish.gd","game/tests/test_electric_smooth_nose.gd","game/tests/test_electric_rounded_front.gd","game/tests/test_electric_quality.gd","game/tests/test_electric_hood_fairing.gd"]:
    assert sha(ROOT/name)==baseline[name],name
    preserved[name]=baseline[name]
concurrent={name:{"task_start_sha256":baseline[name],"current_sha256":sha(ROOT/name),"included_in_checkpoint":False} for name in ["game/vehicle/vehicle_simulation.gd","game/resources/cars/electric.tres"]}
write(E/"concurrent-changes.json",concurrent)
assets=ROOT/"game/assets/vehicles/electric_coachwork_v10"
manifest=read(assets/"manifest.json")
assert manifest["source_sha256"]==sha(ROOT/"game/vehicle/electric_coachwork.gd")
assert manifest["model_sha256"]==preserved["game/vehicle/electric_car_model.gd"]
parts={m["part"]:m for m in manifest["meshes"]}
assert {p.name for p in assets.glob("*.res")}=={m["file"] for m in parts.values()}
assert not (ROOT/"game/assets/vehicles/electric_coachwork_v9").exists()
reuse=read(E/"resource-reuse.json")
assert len(parts)==reuse["current"]==622
for item in reuse["resources"]: assert sha(assets/parts[item["part"]]["file"])==item["sha256"]
validation=read(E/"validation.json")
assert len(validation)==23 and all(v["exit"]==0 for v in validation)
parser=re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures",logtext(E/"logs/parser.log"))
assert parser
results={name:read(E/path) for name,path in {
    "rejected_original":"before-native/clean-bonnet.json","clean_compatibility":"native/clean-bonnet.json","clean_desktop_mobile":"mobile-bonnet/clean-bonnet.json","retained_fairing":"fairing/hood-fairing.json","retained_fairing_desktop_mobile":"mobile-fairing/hood-fairing.json","quality_compatibility":"quality/quality.json","quality_desktop_mobile":"mobile-quality/quality.json","model_compatibility":"model/report.json","model_desktop_mobile":"mobile-model/report.json","retained_nose":"nose/smooth-nose.json","retained_nose_desktop_mobile":"mobile-nose/smooth-nose.json","retained_hood":"hood/hood.json","retained_hood_desktop_mobile":"mobile-hood/hood.json","retained_surface":"surface-finish.json","retained_front":"rounded/rounded-front.json","handling":"handling.json","one_pedal":"one-pedal.json","news":"news-framing.json",
}.items()}
assert results["rejected_original"]["checks"]==43 and results["rejected_original"]["failures"]==12
for name,result in results.items():
    if name!="rejected_original": assert result.get("failures",0)==0,name
app_checks={}
for name in ["garage-race-compatibility","garage-race-mobile"]:
    match=re.search(r"ELECTRIC_UI: (\d+) checks, 0 failures",logtext(E/f"logs/{name}.log"))
    assert match and int(match.group(1))>=60,name
    app_checks[name]=int(match.group(1))
cutoff=(E/"before-hashes.json").stat().st_mtime-5
for p in (ROOT/"build/logs").glob("*/*.log"):
    if p.stat().st_mtime>=cutoff and any(x in logtext(p) for x in ["ELECTRIC_","ONE_PEDAL","test_electric_clean_bonnet.gd"]): copy(p,E/"logs"/f"{p.parent.name}-{p.name}")
old=results["rejected_original"]["metrics"]
new=results["clean_compatibility"]["metrics"]
old_flare=max(v["nose_flare_metres"] for v in old.values() if isinstance(v,dict) and "nose_flare_metres" in v)
new_flare=max(v["nose_flare_metres"] for v in new.values() if isinstance(v,dict) and "nose_flare_metres" in v)
counts=results["model_compatibility"]["triangles"]
report={"date":"2026-10-26","recorded_utc":datetime.now(timezone.utc).isoformat(),
    "requirements":{"ECB01":"remove the marked outward nose hooks and local bonnet flare","ECB02":"a clean independent tapered bonnet outline guided by the supplied Lucid photograph","ECB03":"check the entire physical side seam, symmetry and surround closure in both detail levels/renderers","R01":"retain the fair hood/wing surface, convex nose, budgets, materials, articulation and behavior","G01":"refresh native catalogue/news/all 49 appearance photos","Q01":"verified task-only Git checkpoint"},
    "reference":{"source":"owner-supplied marked game screenshot and Lucid photograph","shipping_reference_bitmap":False,"shipping_brand_logo":False},
    "results":results,"commands":validation,"parser_scripts":int(parser.group(1)),"actual_app_checks":app_checks,
    "measurements":{"original_outward_flare_metres":old_flare,"corrected_outward_flare_metres":new_flare,"original_plan_angles":[old["full_edge_1"]["minimum_plan_angle"],old["full_edge_1"]["maximum_plan_angle"]],"corrected_plan_angles":[new["full_edge_1"]["minimum_plan_angle"],new["full_edge_1"]["maximum_plan_angle"]]},
    "preserved_task_start_sha256":preserved,"concurrent_preserved_changes":concurrent,
    "resources":{k:v for k,v in reuse.items() if k not in ["resources","comparison","obsolete_bake_outputs_removed"]},
    "source_sha256":sha(ROOT/"game/vehicle/electric_coachwork.gd"),"focused_test_sha256":sha(ROOT/"game/tests/test_electric_clean_bonnet.gd"),
    "triangle_budget":{"unchanged_ceiling":170000,"before_full":169641,"before_simple":66333,"after":counts},
    "cause":"The previous taper was specified in surface UV coordinates and inherited changing fender width. Its two sampled widths passed despite an actual 19.39mm local outward hook in the physical side seams.",
    "correction":"Specify a bowed-front rounded trapezoid in physical plan coordinates, then project it onto the retained master surface. The sides taper independently of fender width; mirrored projection preserves symmetry. Physical-Z alignment and closed cowl endpoints fit the surrounding panels. Both models retain complete bonnet sampling.",
    "fixture_change":"test_electric_hood.gd now uses the revised surround outer-boundary parameterization. Its exact-position, gap-depth, symmetry and closure tolerances are unchanged. The new independent actual-mesh contour and closed-corner checks add coverage; every other original model/fairing/nose/surface test source is exact.",
    "initial_issues":["The exact rejected model fails twelve of the same 43 contour/corner checks; baseline and images remain.","The first physical contour passed the new flare checks but exposed an old full-detail symmetry case and a simpler-model S-turn. Explicit mirrored projection, matching surround diagonals and retained bonnet sampling correct them without relaxed bounds; the later outer-strip case differed by 13.35 micrometres against the unchanged ten-micrometre symmetry bound.","Physical-Z strip alignment initially left the two cowl corner junctions open. Native review caught them; endpoint blending closes them and eight independent actual-corner checks per detail level now guard the loop.","Front and side strips now share eight transverse stations; the flatter rear border retains two. This stays inside the original detailed-model budget.","The first retained fairing Vulkan run printed39 checks/0 failures but did not exit before the unchanged300-second limit. The identical retry passes. Initial validation/logs remain under logs/initial-timeout; Resume reuses prior successful commands without rerunning them."],
    "limitations":["Reload and owner/device appearance, motion and rendering-cost acceptance remain.","The simpler model gains bonnet samples; desktop checks and triangle counts do not measure device performance.","Desktop Mobile is PC Vulkan. Manual-stepping hitch messages are not a frame-pacing measurement.","No physical-device attachment check/test, APK, purchase, live mutation, deployment or owner-process restart. Concurrent work and historical evidence are preserved."],
}
write(E/"report.json",report)
rows=[]
for level in ["full","simple"]:
    for shot in ["marked-angle","top","reference-angle","nose-detail"]:
        rows.append(f'<h2>{level}: {shot}</h2><div class="pair"><figure><figcaption>Before</figcaption><img src="before-native/{level}-{shot}.png"></figure><figure><figcaption>After</figcaption><img src="native/{level}-{shot}.png"></figure></div>')
rows.insert(0,'<h2>Actual Garage: marked angle</h2><div class="pair"><figure><figcaption>Before</figcaption><img src="before-native/garage-marked-angle.png"></figure><figure><figcaption>After</figcaption><img src="native/garage-marked-angle.png"></figure></div>')
(E/"gallery.html").write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><title>Electric clean bonnet outline</title><style>body{margin:32px;background:#172129;color:#edf1f3;font:16px system-ui}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%}figcaption{padding:8px}a{color:#e9c750}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style><h1>Electric clean bonnet outline</h1><p>Matched native views of the marked outward nose hooks and the clean independent tapered outline. Both use identical cameras, paint and light rigs.</p><p><a href="mobile-bonnet/full-marked-angle.png">Desktop Mobile front</a> | <a href="mobile-bonnet/garage-marked-angle.png">Desktop Mobile Garage</a> | <a href="report.json">Actual measurements, commands and limitations</a></p>'''+"\n".join(rows)+"</html>\n",encoding="utf-8")
(ROOT/DOC).write_text(f'''# Electric clean bonnet outline — 2026-10-26

The owner marks two outward hooks near the nose and supplies another Lucid reference, asking for a cleaner bonnet shape. The correction authors an independent tapered plan-view outline and fits it onto the retained smooth hood. [Matched native before/after gallery](evidence/electric-clean-bonnet-2026-10-26/gallery.html), [actual commands and measurements](evidence/electric-clean-bonnet-2026-10-26/report.json), [task-only Git checkpoint](evidence/electric-clean-bonnet-2026-10-26/checkpoint.patch).

| Requirement | Result |
| --- | --- |
| ECB01 | Actual local outward flare falls from {old_flare*1000:.3f}mm to {new_flare*1000:.3f}mm on both sides. The previously reversed seam direction now flows continuously inward toward the front. |
| ECB02 | A rounded trapezoid with a bowed leading edge supplies a clean physical outline. Its geometry is projected onto the original master hood surface, independently of the fender width. No reference bitmap or Lucid logo ships. |
| ECB03 | Actual prepared-mesh checks cover 25/25 full and 25/25 simpler side-seam stations, both mirrored outlines and every inner/outer surround corner. Exact original43/12 is retained; final43/43 Compatibility/desktop Mobile pass. Matched front, top, reference-angle, close-up and actual Garage views accompany the measurements. |
| R01 | All 588 non-bonnet prepared resources are exact originals. The fair body/wing surface and rounded nose remain. Original normal, gap, symmetry, S-turn, finite geometry, articulation and 170000-triangle limits pass without weakened tolerances. |
| G01 / Q01 | Native menu/news/all49 photos refreshed and imported; isolated binary patch checked, applied and byte-compared with the final tree. Shared Git index remains untouched. |

The earlier front/rear width ratio was insufficient: a taper in surface UV coordinates still inherited the fender's bulge and reversed direction locally. New plan coordinates give the bonnet straight, gently tapered sides, a bowed front and rounded corners. Projection runs only during offline construction or missing-cache fallback, with prepared meshes used in normal gameplay. Mirroring the positive-side projection makes both halves consistent. The surrounding strips align in physical Z and blend back to the cowl endpoints, closing the complete loop.

Only `game/vehicle/electric_coachwork.gd` changes at runtime. `test_electric_hood.gd` updates its expected outer-boundary parameterization while retaining every original strict tolerance; the new independent contour and closed-corner checks add coverage. All other original model, body, fairing, nose and quality test sources, assembly, shader, presentation and production cameras remain exact. Physics/configuration hashes are recorded separately and excluded from the geometry checkpoint.

V10 contains622 prepared resources:588 byte-identical originals and34 changed bonnet resources. The exact v9 directory is verified against its archive before retirement. Full/simple counts are{counts['full']}/{counts['simple']}, below the unchanged170000 cap. Full detail adds{counts['full']-169641} triangles; the simpler model adds{counts['simple']-66333} to retain the complete bonnet contour and surface sampling. Other simpler-model geometry remains unchanged.

Pinned Godot4.7.2 validation is recorded in [the executable23-command batch](evidence/electric-clean-bonnet-2026-10-26/run_validation.ps1). Contour43/43, retained fairing39/39, quality60/60, model34/34, nose32/32, hood34/34, body finish34 and rounded front8 pass. Actual App Garage/race{app_checks['garage-race-compatibility']}/{app_checks['garage-race-mobile']}, electric60/one-pedal63, import and parser{parser.group(1)} pass. Initial full-detail/outer-strip symmetry, simple S-turn and cowl-junction failures remain in logs and review images, with their corrections; no bounds were relaxed. One Vulkan fairing process printed39/0 but timed out during exit; the identical retry passes. Its original log/result remain under `logs/initial-timeout`, and `-Resume` reuses already successful checks.

Reload and owner/device appearance, motion and rendering-cost acceptance remain. Desktop Mobile is PC Vulkan. Manual-stepping hitch messages are not a frame-pacing measurement. No physical-device attachment check/test, APK, real purchase, live mutation, deployment or owner-process restart was performed. Concurrent Garage/handling and other work, plus historical evidence, are preserved.
''',encoding="utf-8")
summary=f"ECB01-ECB03/R01/G01/Q01: Owner marks outward bonnet hooks and supplies a new Lucid reference. A clean independent physical-plan outline, mirrored projection and fitted closed surround remove the local{old_flare*1000:.2f}mm flare ({new_flare*1000:.2f}mm after). The entire side seam now tapers inward; actual corner closure is guarded. Exact original43checks/12fail retained; contour43/43, fairing39/39, quality60/60, model34/34, nose32/32, hood34/34, surface34, roundness8, App{app_checks['garage-race-compatibility']}/{app_checks['garage-race-mobile']}, electric60/one-pedal63 and parser{parser.group(1)}/import pass. V10 has622 resources with588 exact non-bonnet originals; full/simple{counts['full']}/{counts['simple']} retain170000 cap. The master body/wing surface, assembly, finishes, input/cameras and handling remain. Only the hood fixture's expected outer parameterization changes; original tolerances remain and new independent contour/corner gates strengthen coverage. Catalogue/news/all49 photos refreshed. Sources, actual commands, native comparisons and task-only checkpoint: {DOC} and docs/evidence/electric-clean-bonnet-2026-10-26/report.json. Reload and owner/device appearance/motion/cost acceptance remain; no attachment/device test, APK, purchase, live mutation, deployment or owner-process restart. Concurrent work preserved."
marker="<!-- ELECTRIC-CLEAN-BONNET-20261026 -->"
block=marker+"\n## Electric clean bonnet outline (2026-10-26)\n"+summary+"\n<!-- /ELECTRIC-CLEAN-BONNET-20261026 -->\n\n"
for name in ["AGENTS.md","DEVELOPMENT_STATUS.md","README.md","docs/README.md"]:
    path=ROOT/name; snap=BEFORE/"documents-at-edit"/name
    if (E/"documents-after"/name).exists(): continue
    if not snap.exists(): copy(path,snap)
    data=snap.read_bytes(); text=data.decode("utf-8")
    assert marker not in text
    nl="\r\n" if b"\r\n" in data else "\n"
    if name in ["AGENTS.md","DEVELOPMENT_STATUS.md"]: text=block.replace("\n",nl)+text
    elif name=="README.md": text=text.replace("# Beat my track"+nl+nl,"# Beat my track"+nl+nl+"The electric car's [clean bonnet outline](docs/ELECTRIC_CLEAN_BONNET_2026_10_26.md) removes the outward nose hooks with a clean tapered seam. Matched native Garage and reference-angle views are linked in the report."+nl+nl,1)
    else: text=text.replace("# Documentation index"+nl+nl,"# Documentation index"+nl+nl+"- [Electric clean bonnet outline (2026-10-26)](ELECTRIC_CLEAN_BONNET_2026_10_26.md): independent physical taper, removed nose hooks and matched native comparisons."+nl,1)
    path.write_bytes(text.encode("utf-8")); copy(path,E/"documents-after"/name)

checkpoint = Path(tempfile.mkdtemp(prefix="electric-clean-bonnet-checkpoint-",dir=ROOT / "build"))
a,b = checkpoint / "a",checkpoint / "b"
a.mkdir(); b.mkdir()
for name in ["game/vehicle/electric_coachwork.gd","game/tests/test_electric_hood.gd","game/assets/menu/electric_illustration_v1.png"]:
    copy(BEFORE/name,a/name); copy(ROOT/name,b/name)
for name in ["AGENTS.md","DEVELOPMENT_STATUS.md","README.md","docs/README.md"]:
    copy(BEFORE/"documents-at-edit"/name,a/name); copy(E/"documents-after"/name,b/name)
for name in ["game/tests/test_electric_clean_bonnet.gd","game/tests/test_electric_clean_bonnet.gd.uid",DOC]: copy(ROOT/name,b/name)
for p in (BEFORE/"electric_coachwork_v9").iterdir(): copy(p,a/"game/assets/vehicles/electric_coachwork_v9"/p.name)
for p in assets.iterdir(): copy(p,b/"game/assets/vehicles/electric_coachwork_v10"/p.name)
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
