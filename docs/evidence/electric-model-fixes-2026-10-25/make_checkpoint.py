"""Record the scoped model fix, including exact old/new prepared-asset deltas."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
REL=OUT.relative_to(ROOT)
BACKUP=ROOT/"build/electric-model-fixes-source"
META=["AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md"]
SOURCE="game/vehicle/electric_coachwork.gd"
NEW=["game/tests/test_electric_surface_finish.gd","game/tests/test_electric_surface_finish.gd.uid","docs/ELECTRIC_MODEL_FIXES_2026_10_25.md"]

def write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(data)

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(args: list[str], cwd: Path, code: int=0) -> bytes:
    p=subprocess.run(args,cwd=cwd,capture_output=True)
    assert p.returncode==code,(args,p.stderr.decode(errors="replace"))
    return p.stdout

def main() -> None:
    # Preserve actual initial failures and final native outputs, including the
    # clean normal import after the concurrent font cache was populated.
    ids=[38972,17804,35724,34404,6388,21004,3116,30784,39588,37656,20864,11888,33108,3716,37184,8112,36080,35496]
    for number in ids:
        path=ROOT/f"build/logs/TestScript-{number}/test-script.log"
        if path.exists(): write(OUT/"logs"/f"TestScript-{number}.log",path.read_bytes())
    write(OUT/"logs/Import-30112.log",(ROOT/"build/logs/Import-30112/import.log").read_bytes())
    assert "ERROR" not in (OUT/"logs/Import-30112.log").read_text(errors="replace")
    poses=["front","rear","side","optics","wheel"]
    for renderer,folder in [("model","before-model"),("mobile-model","before-mobile-model")]:
        for pose in poses:
            write(OUT/folder/("electric-"+pose+".png"),(ROOT/"docs/evidence/electric-model-review-2026-10-25"/renderer/("electric-"+pose+".png")).read_bytes())
    sections=[]
    for renderer,before,label in [("model","before-model","Compatibility"),("mobile-model","before-mobile-model","Desktop Mobile / Vulkan")]:
        for pose in poses:
            sections.append(f'<h2>{label} / {pose}</h2><div class="pair"><figure><figcaption>Before</figcaption><a href="{before}/electric-{pose}.png"><img src="{before}/electric-{pose}.png" alt="Before {pose}"></a></figure><figure><figcaption>After</figcaption><a href="{renderer}/electric-{pose}.png"><img src="{renderer}/electric-{pose}.png" alt="After {pose}"></a></figure></div>')
    gallery='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Electric model fixes</title><style>body{background:#172129;color:#edf1f3;font:16px/1.5 system-ui;max-width:1500px;margin:24px auto;padding:0 20px}h1,h2{line-height:1.2}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%;height:auto}figcaption{padding:8px;background:#24333e}a{color:#e0e7ed}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style><h1>Electric model review fixes / 2026-10-25</h1><p>Matched native cameras and studio setup. Rounded continuous body joins, closed recessed door gaps and formed plate/optical pockets. One-pedal driving, handling and production cameras retain their accepted values.</p><p>Surface34/model34+34/Garage-race59+59/replay60/one-pedal63 checks pass. Full/simple164776/64796 triangles. Desktop Mobile is not a physical-device result. Owner/device appearance and cost acceptance remain.</p>'+''.join(sections)+'</html>'
    write(OUT/"gallery.html",gallery.encode())

    block=("<!-- ELECTRIC-MODEL-FIXES-20261025 -->\n## Electric model construction fixes (2026-10-25)\n"
           "2026-10-25 EMF01-EMF03/R01/Q01: Reviewed EV body joins now share rolled profiles, edge stations and normals; "
           "closed door outlines sit in formed paint channels, and rear plate/lights occupy rounded openings with inset returns/backs. "
           "Actual baked138/138 boundary positions agree with max0.0083deg normal difference in both detail levels; "
           "ray-checked door/pocket depths pass. Surface34/model34Compatibility/34desktopMobile, Garage-race59/59, "
           "electric60/one-pedal63/parser1161/import pass. Catalogue and all49 photos refreshed;519 prepared v4 meshes "
           "replace backed-up v3, full164776/simple64796 triangles within unchanged budget. Initial typed-array, "
           "mesh-name fixture, native join and concurrent-font failures remain recorded without weakened assertions. "
           "Handling/config866d2886/physics0.68, driver/control behavior and production cameras remain. "
           "This closes the three construction findings from the preceding model review; general AAA/device acceptance remains. "
           "Commands, before/after native views, hashes and task-only Git-checked checkpoint: docs/ELECTRIC_MODEL_FIXES_2026_10_25.md "
           "and docs/evidence/electric-model-fixes-2026-10-25/report.json. Reload and owner/device appearance/motion/cost acceptance remain. "
           "No attachment/device test, APK, live mutation, purchase, deployment or owner-process restart; concurrent work preserved.\n"
           "<!-- /ELECTRIC-MODEL-FIXES-20261025 -->\n\n")
    for name in META:
        old=re.sub(rb"<!-- ELECTRIC-MODEL-FIXES-20261025 -->.*?<!-- /ELECTRIC-MODEL-FIXES-20261025 -->\r?\n\r?\n",b"",(ROOT/name).read_bytes(),flags=re.S)
        write(OUT/"checkpoint-base"/name,old)
        write(ROOT/name,block.encode()+old)
    write(OUT/"checkpoint-base"/SOURCE,(OUT/"before/game__vehicle__electric_coachwork.gd.txt").read_bytes())
    unchanged={}
    for name in ["game/resources/cars/electric.tres","game/vehicle/vehicle_simulation.gd","game/vehicle/car_visual.gd","game/vehicle/electric_car_model.gd"]:
        before=OUT/"before"/(name.replace("/","__")+".txt")
        assert before.read_bytes()==(ROOT/name).read_bytes(),name
        unchanged[name]=digest(before)
    manifest=json.loads((ROOT/"game/assets/vehicles/electric_coachwork_v4/manifest.json").read_text())
    assert manifest["source_sha256"]==digest(ROOT/SOURCE)
    root_assets=ROOT/"game/assets/vehicles/electric_coachwork_v4"
    assert {p.name for p in root_assets.iterdir() if p.is_file()}=={"manifest.json"}|{m["file"] for m in manifest["meshes"]}
    assert not (ROOT/"game/assets/vehicles/electric_coachwork_v3").exists()
    originals=json.loads((OUT/"before/asset-sha256.json").read_text())
    for name,value in originals.items(): assert digest(BACKUP/name)==value,name
    photos=list((ROOT/"game/assets/liveries/previews_v2/electric").glob("*.png"))
    assert len(photos)==49
    changed_photos=sum(digest(p)!=digest(BACKUP/p.relative_to(ROOT)) for p in photos)
    assert changed_photos==49
    test_results={}
    for name in ["surface-finish","model/report","mobile-model/report","handling","one-pedal"]:
        result=json.loads((OUT/(name+".json")).read_text())
        assert result["failures"]==0
        test_results[name]=result
    compact_exact=[pose for pose in poses if (OUT/"model"/("compact-"+pose+".png")).read_bytes()==(ROOT/"docs/evidence/electric-model-review-2026-10-25/model"/("compact-"+pose+".png")).read_bytes()]
    report={"date":"2026-10-25","recorded_utc":datetime.now(timezone.utc).isoformat(),
            "requirements":{"EMF01":"continuous rounded primary body joins","EMF02":"closed recessed rear-door seam","EMF03":"formed rear optical and plate recesses","R01":"preserve canonical handling, one pedal, no handbrake, D/R, light bar and production camera"},
            "closed_review_findings":["MREV-F01","MREV-F02","MREV-F03"],
            "results":test_results,"native_ui_checks":{"compatibility":59,"desktop_mobile":59},"parser_scripts":1161,"normal_import":"pass",
            "baked_resources":len(manifest["meshes"]),"refreshed_appearance_photos":changed_photos,
            "byte_exact_compact_capture_comparisons":compact_exact,"unchanged_source_sha256":unchanged,
            "independent_server_manifest":json.loads((OUT/"manifest.json").read_text()),
            "initial_outcomes":["Typed-array conditional return corrected with typed local outline; failed bake logs retained","Initial revised native views passed old tests but showed thin joins; matched edge stations/normals and actual baked-mesh checks correct this","Probe assumed unsanitized decimal node names; fixture uses prefix/geometry lookup, assertions retained","Unimported concurrent Noto Symbols font interrupted art/photos/replay; diagnostic recovery imported it, followed by clean normal import and reruns; localization source untouched"],
            "commands_document":"docs/ELECTRIC_MODEL_FIXES_2026_10_25.md",
            "limits":["Owner/device appearance, motion and frame-pacing acceptance remains","No phone/tablet attachment check or physical-device test","No APK, live mutation, purchase, deployment or owner-process restart","Native manual-stepping hitch logs are not a performance benchmark","Full/simple triangle counts increase within the existing upper bound; no mobile cost claim","Client reload required"],
            "checkpoint":{"path":str(REL/"checkpoint.patch").replace("\\","/"),"baseline":"task-start shared sources/assets, current concurrent metadata with only this task marker removed","git_apply_check":False,"byte_exact":False}}
    assets=[str(p.relative_to(ROOT)).replace("\\","/") for folder in [root_assets,ROOT/"game/assets/liveries/previews_v2/electric"] for p in folder.rglob("*") if p.is_file()]
    assets.append("game/assets/menu/electric_illustration_v1.png")
    source_paths=[SOURCE]+NEW+META
    evidence=[str(p.relative_to(ROOT)).replace("\\","/") for p in OUT.rglob("*") if p.is_file() and p.name not in ["checkpoint.patch","report.json"] and "__pycache__" not in p.parts]
    report["sha256"]={name:digest(ROOT/name) for name in sorted(set(assets+source_paths+evidence))}
    report["removed_assets"]={name:value for name,value in originals.items() if not (ROOT/name).exists()}
    record=OUT/"report.json"
    write(record,(json.dumps(report,indent=2)+"\n").encode())
    number=1
    while (ROOT/f"build/electric-model-fixes-checkpoint-{number}").exists(): number+=1
    stage=ROOT/f"build/electric-model-fixes-checkpoint-{number}"
    before,after=stage/"before",stage/"after"
    for name in META+[SOURCE]: write(before/name,(OUT/"checkpoint-base"/name).read_bytes())
    for name in originals: write(before/name,(BACKUP/name).read_bytes())
    paths=sorted(set(assets+source_paths+evidence+[str(REL/"report.json").replace("\\","/")]))
    for name in paths: write(after/name,(ROOT/name).read_bytes())
    patch=OUT/"checkpoint.patch"
    def make_patch() -> None:
        diff=run(["git","-c","core.autocrlf=false","diff","--no-index","--no-renames","--binary","--","before","after"],stage,1)
        lines=[]
        for line in diff.splitlines(keepends=True):
            if line.startswith((b"diff --git ",b"--- ",b"+++ ")):
                for a,b in [(b"a/before/",b"a/"),(b"b/after/",b"b/"),(b"a/after/",b"a/"),(b"b/before/",b"b/")]: line=line.replace(a,b)
            lines.append(line)
        patch.write_bytes(b"".join(lines))
    def verify(label: str) -> None:
        target=stage/label
        shutil.copytree(before,target)
        run(["git","init","-q"],target)
        run(["git","config","core.autocrlf","false"],target)
        run(["git","apply","--check",str(patch)],target)
        run(["git","apply",str(patch)],target)
        for name in paths: assert (target/name).read_bytes()==(after/name).read_bytes(),name
        for name in report["removed_assets"]: assert not (target/name).exists(),name
    make_patch()
    verify("verify1")
    report["checkpoint"].update(git_apply_check=True,byte_exact=True,after_paths=len(paths),removed_paths=len(report["removed_assets"]))
    write(record,(json.dumps(report,indent=2)+"\n").encode())
    shutil.copyfile(record,after/REL/"report.json")
    make_patch()
    verify("verify2")
    for name,value in report["sha256"].items(): assert digest(ROOT/name)==value,name
    for name,value in unchanged.items(): assert digest(ROOT/name)==value,name
    print(json.dumps({"checkpoint":report["checkpoint"],"hashes_verified":len(report["sha256"]),"patch_bytes":patch.stat().st_size,"compact_exact":compact_exact}))

if __name__=="__main__": main()
