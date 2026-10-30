"""Record the native model review without changing runtime/model/handling files."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import html
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
REL = OUT.relative_to(ROOT)
META = ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]


def write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def command(args: list[str], cwd: Path, code: int = 0) -> bytes:
    p = subprocess.run(args, cwd=cwd, capture_output=True)
    assert p.returncode == code, (args,p.stderr.decode(errors="replace"))
    return p.stdout


def main() -> None:
    findings = [
        {"id":"MREV-F01","priority":"P1","title":"Primary body joins remain too sharp for the requested Compact-level finish",
         "source":"game/vehicle/electric_coachwork.gd","line":138,
         "evidence":["model/electric-optics.png","model/compact-optics.png","mobile-model/electric-optics.png"],
         "observation":"The nose/fender and hood/front transitions form abrupt, slab-like lighting breaks in matched native views. Separate side, hood and front skin patches meet without a shared rolled corner profile. The Compact has more developed edge transitions.",
         "next_change":"Author a continuous corner/edge profile and consistent boundary normals; retain the narrow continuous front light and existing physical dimensions.",
         "classification":"Visual-quality assessment supported by native views and construction; not a gameplay or crash defect."},
        {"id":"MREV-F02","priority":"P2","title":"Rear-door lower seam is visibly unfinished",
         "source":"game/vehicle/electric_coachwork.gd","line":220,
         "evidence":["model/electric-side.png","mobile-model/electric-side.png"],
         "observation":"The rear-door bottom outline starts at Z=0.405, while the existing vertical seam is at Z=0.26. The rear door has no corresponding leading closure because that branch runs only for the front door. This leaves an obvious break in the panel outline. Seams are raised 5mm bars over intact paint.",
         "next_change":"Close the shared rear-door outline and author a consistent recessed panel gap rather than disconnected surface bars.",
         "classification":"Confirmed construction/visual defect."},
        {"id":"MREV-F03","priority":"P2","title":"Rear plate well and lamp housing lack formed recess depth",
         "source":"game/vehicle/electric_coachwork.gd","line":200,
         "evidence":["model/electric-rear.png","mobile-model/electric-rear.png"],
         "observation":"RoundedTail remains an uninterrupted painted skin. PlateWell is placed 0.005 model units outward, RearOpticalHousing 0.006 outward; fascia adds relief to rear_z. These are surface overlays rather than formed pockets, which leaves the rear looking flat beside the Compact.",
         "next_change":"Create actual pocket openings/returns for the plate and optical housing, with restrained edge radii and fitted lenses.",
         "classification":"Confirmed construction; depth/finish judgment is visual."},
    ]
    wrapper = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_electric_model.gd -Graphical "
    variants = {"model":"-RenderingMethod gl_compatibility", "mobile-model":"-RenderingMethod mobile -RenderingDriver vulkan"}
    results = {}
    for folder, flags in variants.items():
        result = json.loads((OUT/folder/"report.json").read_text())
        assert result["checks"] == 34 and result["failures"] == 0
        results[folder] = {"command":wrapper+flags+" -TestArgument --evidence-root=res://../"+str(REL/folder).replace("\\","/"),"result":result}
    cutoff = (OUT/"model/electric-front.png").stat().st_mtime
    for log in (ROOT/"build/logs").glob("TestScript-*/test-script.log"):
        if log.stat().st_mtime >= cutoff and "ELECTRIC_MODEL: 34 checks, 0 failures" in log.read_text(errors="replace"):
            write(OUT/"logs"/(log.parent.name+".log"),log.read_bytes())
            identity = log.parent/"client-build-identity.json"
            if identity.exists(): write(OUT/"logs"/(log.parent.name+"-build.json"),identity.read_bytes())

    sections = []
    for folder,label in [("model","Compatibility"),("mobile-model","Desktop Mobile / Vulkan")]:
        for pose in ["front","rear","side","optics","wheel"]:
            cells = "".join(f'<figure><figcaption>{html.escape(car.title()+" / "+pose)}</figcaption><a href="{folder}/{car}-{pose}.png"><img src="{folder}/{car}-{pose}.png" alt="{car} {pose}"></a></figure>' for car in ["compact","electric"])
            sections.append(f'<h2>{label} / {pose}</h2><div class="pair">{cells}</div>')
    items = "".join(f'<li><b>{f["priority"]}: {html.escape(f["title"])}</b><p>{html.escape(f["observation"])}</p></li>' for f in findings)
    gallery = '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Electric model review</title><style>body{background:#172129;color:#edf1f3;font:16px/1.5 system-ui;max-width:1500px;margin:24px auto;padding:0 20px}h1,h2{line-height:1.2}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%;height:auto}figcaption{padding:8px;background:#24333e}a{color:#dbe9f0}li{margin:20px 0}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style><h1>Electric model review / 2026-10-25</h1><p>Current production models, matched camera poses and studio setup. Visual review only. Both renderers pass 34 technical checks. The electric model still needs finishing work to meet the Compact comparison.</p><ol>'+items+'</ol><p>Full 154,276 / simpler 55,700 triangles. No phone performance or appearance acceptance is inferred from these desktop captures. The existing top diagnostic pose clips the longer car and is excluded from this comparison; no production camera was changed.</p>'+"".join(sections)+'</html>'
    write(OUT/"gallery.html",gallery.encode())

    block = ("<!-- ELECTRIC-MODEL-REVIEW-20261025 -->\n## Electric model visual review (2026-10-25)\n"
             "MREV01-MREV03/Q01: Fresh matched Compact/electric native views pass34 checks per renderer "
             "(Compatibility/desktopMobile), full154276/simple55700 triangles and49/49 day/night light-bar samples. "
             "Visual review still finds sharp primary body joins, an unfinished rear-door lower seam and raised rear plate/lamp overlays instead of formed recesses. "
             "These are open findings, not completed fixes or AAA acceptance. Prioritized source-linked findings, "
             "commands, native comparison, hashes and task-only checkpoint: docs/evidence/electric-model-review-2026-10-25/review.json and gallery.html. "
             "Runtime/model/handling files unchanged. Owner/device appearance and mobile cost acceptance remain; "
             "no attachment/device test, APK, live mutation, purchase, deployment or owner-process restart. Concurrent work preserved.\n"
             "<!-- /ELECTRIC-MODEL-REVIEW-20261025 -->\n\n")
    for name in META:
        old = re.sub(rb"<!-- ELECTRIC-MODEL-REVIEW-20261025 -->.*?<!-- /ELECTRIC-MODEL-REVIEW-20261025 -->\r?\n\r?\n",b"",(ROOT/name).read_bytes(),flags=re.S)
        write(OUT/"checkpoint-base"/name,old)
        write(ROOT/name,block.encode()+old)

    sources = ["game/vehicle/electric_car_model.gd","game/vehicle/electric_coachwork.gd","game/vehicle/compact_coachwork.gd","game/vehicle/compact_finish.gd","game/vehicle/car_visual.gd","game/tests/test_electric_model.gd","game/ui/showroom_studio.gd","game/assets/vehicles/electric_coachwork_v3/manifest.json","game/resources/cars/electric.tres"]
    report = {"date":"2026-10-25","recorded_utc":datetime.now(timezone.utc).isoformat(),"requirements":{"MREV01":"review the electric visual model against Compact","MREV02":"validate current source/cache/geometry and day/night light continuity","MREV03":"prioritize concrete remaining finish defects"},"assessment":"Current electric model still falls short of Compact-level visual finish; three open findings. Technical tests are not an AAA appearance approval.","findings":findings,"validation":results,"scope":"Review and evidence only; no runtime/model/handling edits.","limitations":["No physical phone/tablet test or attachment check","No mobile performance inference from desktop triangle counts","No APK, purchase, live mutation, deployment or owner-process restart","Matched diagnostic top shot clips the longer car and is excluded from comparison","No moving light/camera sweep; close-up wheel-arch/tread highlights need further motion inspection before treating them as a separate defect"],"gallery":str(REL/"gallery.html").replace("\\","/"),"checkpoint":{"path":str(REL/"checkpoint.patch").replace("\\","/"),"baseline":"concurrent workspace, only review metadata removed","git_apply_check":False,"byte_exact":False}}
    paths = sources + META + [str(p.relative_to(ROOT)).replace("\\","/") for p in OUT.rglob("*") if p.is_file() and p.name not in ["checkpoint.patch","review.json"] and "__pycache__" not in p.parts]
    report["sha256"] = {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(set(paths))}
    record = OUT/"review.json"
    write(record,(json.dumps(report,indent=2)+"\n").encode())
    index = 1
    while (ROOT/f"build/electric-model-review-checkpoint-{index}").exists(): index+=1
    stage = ROOT/f"build/electric-model-review-checkpoint-{index}"
    before,after = stage/"before",stage/"after"
    for name in META: write(before/name,(OUT/"checkpoint-base"/name).read_bytes())
    changed = META + [str(p.relative_to(ROOT)).replace("\\","/") for p in OUT.rglob("*") if p.is_file() and p.name != "checkpoint.patch" and "__pycache__" not in p.parts]
    for name in changed: write(after/name,(ROOT/name).read_bytes())
    patch = OUT/"checkpoint.patch"
    def make_patch() -> None:
        diff = command(["git","-c","core.autocrlf=false","diff","--no-index","--no-renames","--binary","--","before","after"],stage,1)
        lines=[]
        for line in diff.splitlines(keepends=True):
            if line.startswith((b"diff --git ",b"--- ",b"+++ ")):
                for a,b in [(b"a/before/",b"a/"),(b"b/after/",b"b/"),(b"a/after/",b"a/"),(b"b/before/",b"b/")]: line=line.replace(a,b)
            lines.append(line)
        patch.write_bytes(b"".join(lines))
    def verify(label: str) -> None:
        dest=stage/label
        shutil.copytree(before,dest)
        command(["git","init","-q"],dest)
        command(["git","config","core.autocrlf","false"],dest)
        command(["git","apply","--check",str(patch)],dest)
        command(["git","apply",str(patch)],dest)
        for name in changed: assert (dest/name).read_bytes()==(after/name).read_bytes(), name
    make_patch()
    verify("verify1")
    report["checkpoint"].update(git_apply_check=True,byte_exact=True,changed_paths=len(changed))
    write(record,(json.dumps(report,indent=2)+"\n").encode())
    shutil.copyfile(record,after/REL/"review.json")
    make_patch()
    verify("verify2")
    for name,value in report["sha256"].items(): assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==value, name
    print(json.dumps({"findings":len(findings),"native_checks":68,"checkpoint":report["checkpoint"],"hashes":len(report["sha256"])}))


if __name__ == "__main__":
    main()
