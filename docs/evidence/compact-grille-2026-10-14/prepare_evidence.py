"""Scoped original-asset receipt and review checkpoint; no Git index changes."""
from pathlib import Path
import hashlib
import json
import subprocess

TASK = Path(__file__).resolve().parent
ROOT = TASK.parents[2]
BEFORE = TASK / "before"

NOTES = {
    "AGENTS.md": "## Compact fabricated front grille override (2026-10-14)\nThe owner requests an AAA-target compact grille. Use a real shared steel/fascia cooling aperture, a closed bowed satin surround, five capped chamfered slats, recessed seated fasteners and a complete deep radiator/duct. Preserve the four-lamp silhouette, tyre/hood/bumper clearance, kits/paint/livery/local condition, articulation, reflections and canonical behavior. Three immutable meshes serve full/simple cars; grille-only condition eligibility and prepared restoration retain clean finishes. Keep16 kit photos/1260 prepared parts; catalog maxima169730/65934 stay below170000. See `docs/COMPACT_GRILLE_2026_10_14.md` for native both-renderer views, actual checks, hash-exact unaffected assets and scoped checkpoint. Owner/physical-phone acceptance remains; no APK/deployment.\n\n",
    "DEVELOPMENT_STATUS.md": "2026-10-14 CGR01-CGR04/V04-V06/G01/R01/Q01: owner AAA-target compact grille. Real steel/fascia cooling aperture, bowed satin surround, five closed 46mm louvers, seated slotted hardware and complete recessed radiator/duct. Three shared immutable meshes/1454tris; four-lamp/kit/wheel/paint/condition/camera/reflection/canonical behavior retained. Stock105374/40950; all13000 catalog maxima169730/65934 below170000. Native49full/49simple/24other shadows hash-exact;86kit+49compact livery photos,16photo cache/1260parts retained. Geometry179/catalog1543/racing75/weathering820/incremental346+346/reflections25+25/parser742 pass; both-renderer16final views. No phone/APK/deploy/FPS or AAA certification claim. Actual commands, scoped checkpoint and owner/device acceptance: docs/COMPACT_GRILLE_2026_10_14.md.\n\n",
    "docs/PHASE_0_PLAN.md": "2026-10-14 CGR01-CGR04/V04-V06/G01/R01/Q01: actual compact grille refinement: real shared cooling hole, closed satin surround/slats, fitted fasteners and deep radiator; retained cosmetics/condition/prepared restoration/kits/articulation/camera/reflections/canonical behavior. Geometry179/catalog1543/racing75/weathering820/incremental346+346/reflections25+25/parser742 pass; catalog169730/65934, three1454tri meshes, native both-renderer views and bounded refreshed photos. No physical-phone test/APK/deploy/FPS or AAA certification claim. Owner/device acceptance and task-only checkpoint: docs/COMPACT_GRILLE_2026_10_14.md.\n\n",
    "licenses/ASSETS.md": "Compact fabricated front grille (2026-10-14): original native rounded cooling aperture, closed bowed surround/capped louvers, slotted seated fasteners and radiator/duct, authored in game/vehicle/compact_grille.gd. No external model/texture/service/reference pixels. One full/one simple native face and compact body shadow refreshed;49+49coachwork/24other shadows exact.86kit+49compact livery photos are offline original-model captures. Source hashes, actual checks and remaining owner/device acceptance: docs/COMPACT_GRILLE_2026_10_14.md and its asset receipt.\n\n",
    "game/assets/vehicles/compact_coachwork_v3/PROVENANCE.md": "Front-grille refinement (2026-10-14): original real shared steel/fascia aperture and authored closed bowed surround, capped deep louvers, seated slotted hardware and complete radiator/duct. Editable source game/vehicle/compact_grille.gd; no external mesh/texture/service/reference pixels. Only front_coachwork.res changes;49full resources remain hash-exact,50total713196bytes. Corresponding simple front/body shadow and original native photos are refreshed independently. Actual captures/checks/scoped checkpoint and owner/device acceptance: docs/COMPACT_GRILLE_2026_10_14.md.\n\n",
}

for relative, note in NOTES.items():
    target = ROOT / relative
    content = target.read_text(encoding="utf-8")
    clean = content.replace(note, "", 1) if note in content else content
    snapshot = BEFORE / relative
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_text(clean, encoding="utf-8")
    if "--notes" in __import__("sys").argv and note not in content:
        if relative == "AGENTS.md":
            updated = clean.replace("# Project agent instructions\n\n", "# Project agent instructions\n\n"+note, 1)
            assert updated != clean
        else:
            updated = note+clean
        target.write_text(updated, encoding="utf-8")

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def reconstruct(relative, edits):
    target = BEFORE / relative
    if target.exists():
        return
    with (ROOT / relative).open(encoding="utf-8", newline="") as source:
        content = source.read()
    ending = "\r\n" if "\r\n" in content else "\n"
    normalized = content.replace("\r\n", "\n")
    for new, old in edits:
        assert new in normalized, (relative, new)
        normalized = normalized.replace(new, old, 1)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(normalized.replace("\n", ending).encode())

reconstruct("game/tests/bake_compact_kit_previews.gd", [(
    '\tif "--photos-only" in OS.get_cmdline_user_args():\n\t\tprint("KIT_PHOTO_BAKE: ",photo_count," ",renderer," previews; prepared part meshes retained")\n\t\tquit()\n\t\treturn\n', "")])
reconstruct("game/tests/bake_racing_car_models.gd", [
    ('\tvar front_only: bool = "--compact-front-only" in OS.get_cmdline_user_args()\n\tif front_only: report = JSON.parse_string(FileAccess.get_file_as_string(RacingCarModels.ASSET_ROOT.path_join("manifest.json")))\n', ""),
    ('\t\tif front_only and id!="compact": continue\n', ""),
    ('\t\tif front_only: details.assign(report.cars.compact)\n', ""),
    ('\t\t\tif front_only and index!=0: continue\n', ""),
    ('\t\t\tvar detail: Dictionary = {"frame":index,"source_triangles":original_count,"triangles":chosen.size()/3,"lod_error":error,"vertices":compact.size()}\n\t\t\tif front_only: details[index] = detail\n\t\t\telse: details.append(detail)\n', '\t\t\tdetails.append({"frame":index,"source_triangles":original_count,"triangles":chosen.size()/3,"lod_error":error,"vertices":compact.size()})\n'),
    ('\t\tif not front_only or key=="front_coachwork_simple": assert(ResourceSaver.save(resources[key],path,ResourceSaver.FLAG_COMPRESS) == OK)\n', '\t\tassert(ResourceSaver.save(resources[key],path,ResourceSaver.FLAG_COMPRESS) == OK)\n'),
])

coach = ROOT / "game/assets/vehicles/compact_coachwork_v3"
manifest_path = coach / "manifest.json"
manifest = json.loads((BEFORE / "game/assets/vehicles/compact_coachwork_v3/manifest.json").read_text())
manifest["files"] = {p.name: {"bytes": p.stat().st_size, "sha256": digest(p)} for p in sorted(coach.glob("*.res"))}
manifest["total_bytes"] = sum(item["bytes"] for item in manifest["files"].values())
manifest["visual_revision"] = "compact-fabricated-front-grille-2026-10-14"
manifest["sources"].append("res://vehicle/compact_grille.gd")
manifest_path.write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")

receipt = {"coachwork": {}, "simple": {}, "kit_photos": {}, "livery_photos": {}, "catalog": json.loads((TASK/"catalog/catalog.json").read_text())}
for name, directory in [("coachwork", "compact_coachwork_v3"), ("simple", "racing_simple_v1")]:
    current = ROOT / "game/assets/vehicles" / directory
    prior = BEFORE / "game/assets/vehicles" / directory
    for p in sorted(current.rglob("*.res")):
        relative = p.relative_to(current)
        receipt[name][relative.as_posix()] = {"sha256": digest(p), "bytes": p.stat().st_size, "changed": digest(p)!=digest(prior/relative)}
for p in sorted((ROOT/"game/assets/vehicles/compact_kits_v1/previews").rglob("*.png")):
    relative = p.relative_to(ROOT/"game/assets/vehicles/compact_kits_v1/previews")
    receipt["kit_photos"][relative.as_posix()] = {"sha256":digest(p),"changed":digest(p)!=digest(BEFORE/"game/assets/vehicles/previews"/relative)}
for p in sorted((ROOT/"game/assets/liveries/previews_v2/compact").glob("*.png")):
    receipt["livery_photos"][p.name] = {"sha256":digest(p),"changed":digest(p)!=digest(BEFORE/"game/assets/liveries/previews_v2/compact"/p.name)}
(TASK/"asset-receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")

if "--checkpoint" in __import__("sys").argv:
    selected = [
        "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "licenses/ASSETS.md",
        "docs/COMPACT_GRILLE_2026_10_14.md",
        "game/vehicle/compact_grille.gd", "game/vehicle/compact_grille.gd.uid",
        "game/vehicle/compact_detail.gd", "game/vehicle/compact_coachwork.gd", "game/vehicle/vehicle_weathering.gd",
        "game/ui/compact_kit_thumbnail.gd", "game/tests/bake_compact_kit_previews.gd",
        "game/tests/bake_racing_car_models.gd", "game/tests/bake_livery_previews.gd",
        "game/tests/capture_compact_grille.gd", "game/tests/capture_compact_grille.gd.uid",
        "game/tests/test_compact_grille.gd", "game/tests/test_compact_grille.gd.uid",
        "game/assets/vehicles/compact_coachwork_v3/front_coachwork.res",
        "game/assets/vehicles/compact_coachwork_v3/manifest.json", "game/assets/vehicles/compact_coachwork_v3/PROVENANCE.md",
        "game/assets/vehicles/racing_simple_v1/compact/front_coachwork_simple.res",
        "game/assets/vehicles/racing_simple_v1/compact_shadow_0.res", "game/assets/vehicles/racing_simple_v1/manifest.json",
    ]
    selected.extend(str(p.relative_to(ROOT)).replace("\\","/") for p in (ROOT/"game/assets/vehicles/compact_kits_v1/previews").rglob("*.png"))
    selected.extend(str(p.relative_to(ROOT)).replace("\\","/") for p in (ROOT/"game/assets/liveries/previews_v2/compact").glob("*.png"))
    chunks = []
    for relative in selected:
        old = BEFORE / relative
        if relative.startswith("game/assets/vehicles/compact_kits_v1/previews/"):
            old = BEFORE / "game/assets/vehicles/previews" / relative.split("/previews/",1)[1]
        new = ROOT / relative
        assert new.exists(), relative
        previous = old.relative_to(ROOT).as_posix() if old.exists() else "NUL"
        result = subprocess.run(["git","diff","--no-index","--binary","--",previous,relative],cwd=ROOT,capture_output=True)
        assert result.returncode in [0,1],result.stderr.decode()
        output = result.stdout
        if old.exists():
            output = output.replace(("a/"+previous).encode(),("a/"+relative).encode())
            output = output.replace(("b/"+previous).encode(),("b/"+relative).encode())
        chunks.append(output)
    (TASK/"scoped-change.patch").write_bytes(b"".join(chunks))
print("GRILLE_ASSETS:",manifest["total_bytes"],"bytes; changed coachwork",[k for k,v in receipt["coachwork"].items() if v["changed"]],"changed simple",[k for k,v in receipt["simple"].items() if v["changed"]])
