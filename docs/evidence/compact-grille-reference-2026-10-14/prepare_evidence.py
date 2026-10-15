"""Original native asset receipt and task-only review patch."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

TASK = Path(__file__).resolve().parent
ROOT = TASK.parents[2]
BEFORE = TASK / "before"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

coach_root = ROOT / "game/assets/vehicles/compact_coachwork_v3"
manifest = json.loads((BEFORE/"game/assets/vehicles/compact_coachwork_v3/manifest.json").read_text())
manifest["files"] = {p.name:{"bytes":p.stat().st_size,"sha256":sha(p)} for p in sorted(coach_root.glob("*.res"))}
manifest["total_bytes"] = sum(item["bytes"] for item in manifest["files"].values())
manifest["visual_revision"] = "compact-reference-front-2026-10-14"
manifest["sources"].extend(["res://vehicle/compact_front_lamps.gd","res://vehicle/compact_headlamp.gdshader"])
(coach_root/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
receipt = {"native":{},"kit_photos":{},"livery_photos":{},"catalog":json.loads((TASK/"catalog/catalog.json").read_text())}
for directory in ["compact_coachwork_v3","racing_simple_v1"]:
    current = ROOT/"game/assets/vehicles"/directory
    for p in sorted(current.rglob("*.res")):
        rel = p.relative_to(current)
        prior = BEFORE/"game/assets/vehicles"/directory/rel
        receipt["native"][directory+"/"+rel.as_posix()] = {"sha256":sha(p),"bytes":p.stat().st_size,"changed":sha(p)!=sha(prior)}
for p in sorted((ROOT/"game/assets/vehicles/compact_kits_v1/previews").rglob("*.png")):
    rel = p.relative_to(ROOT/"game/assets/vehicles/compact_kits_v1/previews")
    receipt["kit_photos"][rel.as_posix()] = {"sha256":sha(p),"changed":sha(p)!=sha(BEFORE/"game/assets/vehicles/previews"/rel)}
for p in sorted((ROOT/"game/assets/liveries/previews_v2/compact").glob("*.png")):
    receipt["livery_photos"][p.name] = {"sha256":sha(p),"changed":sha(p)!=sha(BEFORE/"game/assets/liveries/previews_v2/compact"/p.name)}
(TASK/"asset-receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")

notes_path = TASK/"notes.json"
if notes_path.exists():
    for relative,note in json.loads(notes_path.read_text()).items():
        target = ROOT/relative
        content = target.read_text(encoding="utf-8")
        clean = content.replace(note,"",1) if note in content else content
        baseline = BEFORE/relative
        baseline.parent.mkdir(parents=True,exist_ok=True)
        baseline.write_text(clean,encoding="utf-8")
        if "--notes" in sys.argv and note not in content:
            updated = clean.replace("# Project agent instructions\n\n","# Project agent instructions\n\n"+note,1) if relative=="AGENTS.md" else note+clean
            target.write_text(updated,encoding="utf-8")

if "--checkpoint" in sys.argv:
    selected = [
        "AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md","licenses/ASSETS.md",
        "docs/COMPACT_GRILLE_REFERENCE_2026_10_14.md",
        "game/vehicle/compact_grille.gd","game/vehicle/compact_detail.gd","game/vehicle/car_visual.gd",
        "game/vehicle/compact_front_lamps.gd","game/vehicle/compact_front_lamps.gd.uid",
        "game/vehicle/compact_headlamp.gdshader","game/vehicle/compact_headlamp.gdshader.uid",
        "game/ui/compact_kit_thumbnail.gd","game/tests/test_compact_grille.gd","game/tests/capture_compact_grille.gd",
        "game/assets/vehicles/compact_coachwork_v3/front_coachwork.res",
        "game/assets/vehicles/compact_coachwork_v3/manifest.json","game/assets/vehicles/compact_coachwork_v3/PROVENANCE.md",
        "game/assets/vehicles/racing_simple_v1/compact/front_coachwork_simple.res",
        "game/assets/vehicles/racing_simple_v1/compact_shadow_0.res","game/assets/vehicles/racing_simple_v1/manifest.json",
    ]
    selected += [p.relative_to(ROOT).as_posix() for p in (ROOT/"game/assets/vehicles/compact_kits_v1/previews").rglob("*.png")]
    selected += [p.relative_to(ROOT).as_posix() for p in (ROOT/"game/assets/liveries/previews_v2/compact").glob("*.png")]
    shared_notes = json.loads(notes_path.read_text()) if notes_path.exists() else {}
    selected = [p for p in selected if p not in shared_notes]+[p for p in selected if p in shared_notes]
    chunks = []
    for relative in selected:
        prior = BEFORE/relative
        if relative in shared_notes:
            # Other owner tasks can prepend status notes during the image diffs.
            # Refresh the baseline immediately before this small text diff.
            current = (ROOT/relative).read_text(encoding="utf-8")
            assert shared_notes[relative] in current,relative
            prior.write_text(current.replace(shared_notes[relative],"",1),encoding="utf-8")
        if relative.startswith("game/assets/vehicles/compact_kits_v1/previews/"):
            prior = BEFORE/"game/assets/vehicles/previews"/relative.split("/previews/",1)[1]
        old = prior.relative_to(ROOT).as_posix() if prior.exists() else "NUL"
        args = ["git","diff","--no-index","--binary"]
        if relative in ["AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md","licenses/ASSETS.md"]: args.append("--unified=1")
        result = subprocess.run(args+["--",old,relative],cwd=ROOT,capture_output=True)
        assert result.returncode in [0,1],result.stderr.decode()
        chunk = result.stdout
        if prior.exists(): chunk = chunk.replace(("a/"+old).encode(),("a/"+relative).encode()).replace(("b/"+old).encode(),("b/"+relative).encode())
        chunks.append(chunk)
    (TASK/"scoped-change.patch").write_bytes(b"".join(chunks))
print("REFERENCE_GRILLE_ASSETS",manifest["total_bytes"],"bytes; changed native:",[k for k,v in receipt["native"].items() if v["changed"]])
