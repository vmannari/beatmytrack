"""Save read-only review findings and a diagnostic/document-only checkpoint."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

EV = Path(__file__).resolve().parent
ROOT = EV.parents[2]
DOC = Path("docs/KART_CONSTRUCTION_REVIEW_2026_10_25.md")
TAG = "KART-CONSTRUCTION-REVIEW-20261025"


def read(p): return json.loads(Path(p).read_text(encoding="utf-8-sig"))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p, data): Path(p).write_bytes((json.dumps(data, indent=2)+"\n").encode())


hashes = read(EV/"model-hashes-before.json")
assert all(sha(ROOT/p) == value for p,value in hashes.items())
metrics = {name:read(EV/name/"metrics.json") for name in ["gl_compatibility","mobile"]}
assert metrics["gl_compatibility"]["detail"] == metrics["mobile"]["detail"]
manifest = read(ROOT/"game/assets/vehicles/kart_refined_v1/manifest.json")
for name, expected in metrics["gl_compatibility"]["sources"].items():
    assert sha(ROOT/"game/vehicle"/name) == expected
    assert manifest[{"kart_model.gd":"model_sha256","kart_geometry.gd":"geometry_sha256","kart_driver.gd":"driver_sha256","kart_helmet.gd":"helmet_sha256"}[name]] == expected
findings = [
    {"id":"KCR01","priority":"P2","title":"Seat support stays terminate behind the bucket","source":"game/vehicle/kart_model.gd:40","detail":"Both stay tips end at (+/-0.25,0.54,0.55); their actual tube rim is 0.19084 model metres from the detailed bucket and 0.19185 from the simple bucket. The seat repositioning leaves the old supports visibly disconnected.","recommendation":"Route the existing supports to actual bucket attachment points and add fitted mounting hardware.","image":"gl_compatibility/full-batched-seat-support.png"},
    {"id":"KCR02","priority":"P2","title":"The helmet underside exposes the empty interior around the neck","source":"game/vehicle/kart_helmet.gd:124","detail":"Native low side/rear views show the grey showroom background through the lower helmet opening on both sides of the narrow balaclava. The lining return is an open annular strip; no opaque inner head/lining fills these visible sight lines.","recommendation":"Fit an opaque dark inner head/lining to close the visible gaps while retaining the current outer helmet and short-neck silhouette.","image":"mobile/full-batched-seat-support.png"},
    {"id":"KCR03","priority":"P2","title":"Sleeve and trouser roots remain abrupt separate joins","source":"game/vehicle/kart_driver.gd:85; game/vehicle/kart_driver.gd:91","detail":"The open root rings are not fully contained by the torso: 13/24 sleeve and 19/24 trouser root samples lie outside it in the detailed model. Maximum ring-to-torso distances are 0.04498/0.03675 model metres; simple equivalents are about 0.04544/0.03822. Shoulder close-ups show sharp unstitched tube boundaries instead of a shaped cloth transition. Sidepods/seat hide portions of the trouser rims, so these metrics alone are not a claim that every outside sample is visible.","recommendation":"Build fitted shared shoulder/hip transition rings or join the suit topology, preserving the accepted limb lengths, hand/boot locations and seat clearance.","image":"mobile/simple-shoulder-front.png"}
]
summary = (
    "## Kart construction review, findings pending (2026-10-25)\n"
    "KCR01-KCR03/R01/Q01: Read-only review of the current kart confirms three P2 construction findings: seat stays end about 0.191 model metres behind the bucket; the helmet underside shows background around the narrow neck; separate sleeve/trouser roots retain abrupt exposed boundaries. "
    "Full/simple and original/batched native close-ups agree in Compatibility and desktop Mobile; mesh measurements are identical across renderers. Corrected short neck and leg/torso proportions are retained. The existing 93520/28706-triangle geometry, all prepared resources/photos, kart handling and cameras remain untouched; current asset/source hashes match the preceding native regression evidence. "
    "No model fixes are made by this review. Findings, source lines, actual commands, images, measurement limits and a diagnostic/document-only checkpoint: docs/KART_CONSTRUCTION_REVIEW_2026_10_25.md and docs/evidence/kart-construction-review-2026-10-25/report.json. Corrective work and owner/device appearance acceptance remain. No device attachment check/test, APK, purchase, live mutation, deployment or owner-process restart; concurrent work preserved."
)


def strip(raw):
    return re.sub(rb"(?ms)^<!-- "+TAG.encode()+rb" -->\r?\n.*?^<!-- /"+TAG.encode()+rb" -->\r?\n(?:\r?\n)?",b"",raw)


shared = [Path(p) for p in ["AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md"]]
for rel in shared:
    p = ROOT/rel
    raw = strip(p.read_bytes())
    nl = b"\r\n" if b"\r\n" in raw else b"\n"
    block = (f"<!-- {TAG} -->\n{summary}\n<!-- /{TAG} -->\n\n").encode().replace(b"\n",nl)
    p.write_bytes(block+raw)
doc = """# Kart construction review — 2026-10-25

The owner asks to review the current go-kart model after the helmet, body, seat, leg and neck corrections. This is a read-only model review. No production geometry, materials, photos, handling, camera or existing test assertion is changed.

Three findings remain, each P2 (visible construction quality; no canonical gameplay defect identified):

1. **KCR01 — Seat support stays are detached from the bucket.** The two metal struts visible behind the seat still terminate at (+/-0.25, 0.54, 0.55), while the corrected bucket has moved forward. Actual end-rim-to-seat-triangle distances are **0.190843** detailed and **0.191854** simple model metres. This is a real gap in the native batched model, not a shadow. Route the stays to fitted bucket mounts. Source: [kart_model.gd:40](../game/vehicle/kart_model.gd#L40). Evidence: [Compatibility](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-batched-seat-support.png), [Mobile](evidence/kart-construction-review-2026-10-25/mobile/full-batched-seat-support.png).

2. **KCR02 — Helmet underside has visible empty gaps around the neck.** The same low side/rear close-ups show the showroom background through the lower opening. The shell has an open annular lining strip, with a narrower balaclava beneath it. Fit a dark opaque inner head/lining around the wearer while retaining the outer shell and shorter-neck pose. Source: [kart_helmet.gd:124](../game/vehicle/kart_helmet.gd#L124), [kart_driver.gd:74](../game/vehicle/kart_driver.gd#L74). Evidence: [native underside in context](evidence/kart-construction-review-2026-10-25/mobile/full-batched-seat-support.png). This is a visual observation; no numerical head-closure test is claimed.

3. **KCR03 — Shoulder/hip joins still look like separate intersecting cloth pieces.** The sleeve and trouser patches have open root rings. In each detailed sleeve 13/24 root samples fall outside the torso; each trouser root has 19/24. Maximum rim-to-torso distances are **0.04498/0.03675** model metres. The simpler model gives 7/12 and 9/12, with **0.04544/0.03822** distances. Shoulder close-ups show abrupt edges and an angular shoulder transition. Blend fitted shared seam rings or join topology while preserving the corrected limb lengths and control/seat fit. Source: [kart_driver.gd:85](../game/vehicle/kart_driver.gd#L85), [sleeves:91](../game/vehicle/kart_driver.gd#L91). Evidence: [detailed shoulder](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-shoulder-front.png), [simple shoulder](evidence/kart-construction-review-2026-10-25/mobile/simple-shoulder-front.png), [rear/batched shoulder](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-batched-shoulder.png). Sidepods and the seat conceal parts of the trouser rims; outside-torso counts alone do not prove every sample is visible.

The helmet/neck and leg/torso corrections now give a more coherent seated silhouette. The main next work is attachment and seam construction. The most recent actual Garage/race and overhead captures were inspected alongside front/rear/top/side images, and their kart source/assets still match. No new wheel/nose, engine/tyre, exhaust-clamp or sleeve-piping regression was identified from the reviewed images. This is not a universal absence-of-intersections or device-performance claim.

`game/tests/review_kart_model.gd` is a new read-only diagnostic. It loads the actual prepared detailed and racing geometry, finds stays by their cached mesh identity, measures tube end vertices against seat triangles, and checks cloth root rings against the torso. Its diagnostic cameras are separate from production cameras. It saves original and production-batched close-ups; no part is hidden in the evidence images. Each renderer saves sixteen images. Both renderer measurements agree exactly. Measurements are in unscaled model metres, not real-world dimensions. The visible triangle budgets remain 93,520/28,706.

Actual commands use pinned Godot 4.7.2 through scripts/dev.ps1, isolated APPDATA/LOCALAPPDATA under build/kart-construction-review, and approved native Windows certificate-store access:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-review-2026-10-25/run.ps1 -Job review
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-review-2026-10-25/run.ps1 -Job review -Renderer mobile
python docs/evidence/kart-construction-review-2026-10-25/finalize.py
```

The review scripts compile and execute successfully in both renderers. Their zero process exits mean that the diagnostics ran, not that the model is free of findings. Existing regression results are the preceding short-neck report's fit32/proportions24/model86+86/retained172/Garage-race15+15/kart42/parser1184; they were **not rerun in this review**. Exact current source/asset hashes and manifest pins confirm the reviewed geometry matches that prior evidence. The current review adds checks for construction areas those suites do not cover. No assertion is relaxed.

[report.json](evidence/kart-construction-review-2026-10-25/report.json) records the findings, actual source hashes, measurements and a diagnostic/document-only isolated Git checkpoint. Its patch passes whitespace and reverse-application checks and leaves the normal index untouched. The model and photos remain unchanged; corrective work is pending.

No device attachment check/test, APK, real authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan renderer test. Owner/device visual and motion/cost acceptance remain.
"""
(ROOT/DOC).write_bytes(doc.encode())
sources = [Path("game/tests/review_kart_model.gd")]
uid = Path("game/tests/review_kart_model.gd.uid")
if (ROOT/uid).exists(): sources.append(uid)
files = sources+shared+[DOC]
save(EV/"review-file-hashes.json",{p.as_posix():sha(ROOT/p) for p in files})
checkpoint = ROOT/"build/kart-construction-review/checkpoint"
assert not checkpoint.exists()
checkpoint.mkdir(parents=True)
index_hash = sha(ROOT/".git/index")
env = {k:v for k,v in os.environ.items() if k not in ["GIT_DIR","GIT_WORK_TREE","GIT_INDEX_FILE"]}


def git(*args): return subprocess.run(["git","-c","core.autocrlf=false","-c","user.name=Codex","-c","user.email=codex@local.invalid","-C",str(checkpoint),*args],env=env,check=True,capture_output=True,text=True).stdout.strip()
def copy(source,relative):
    target = checkpoint/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,target)


git("init","--quiet")
copy(ROOT/".gitattributes",Path(".gitattributes"))
for rel in shared:
    p = checkpoint/rel
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_bytes(strip((ROOT/rel).read_bytes()))
git("add","--all")
git("commit","--quiet","-m","Current shared documentation baseline before kart construction review")
base = git("rev-parse","HEAD")
for p in files: copy(ROOT/p,p)
git("add","--all")
git("diff","--cached","--check")
git("commit","--quiet","-m","Record kart construction findings and read-only native diagnostic")
commit = git("rev-parse","HEAD")
git("diff","--binary","--output="+str(EV/"task.patch"),"HEAD~1","HEAD")
git("apply","--reverse","--check",str(EV/"task.patch"))
assert not git("status","--porcelain") and sha(ROOT/".git/index") == index_hash
assert all(sha(ROOT/p) == value for p,value in hashes.items())
(EV/"checkpoint-stat.txt").write_bytes((git("show","--stat","--oneline","HEAD")+"\n").encode())
save(EV/"report.json",{"date":"2026-10-25","scope":"Read-only kart model review","requirements":["KCR01","KCR02","KCR03","R01","Q01"],"findings":findings,"native_metrics":metrics,"model_source_asset_hashes_unchanged":hashes,"prior_regression_report":"docs/evidence/kart-short-neck-2026-10-25/report.json","prior_tests_rerun":False,"commands":"run.ps1; review-command.json; review-mobile-command.json","diagnostic_and_docs_hashes":"review-file-hashes.json","checkpoint":{"repository":str(checkpoint),"base":base,"commit":commit,"patch":"task.patch","sha256":sha(EV/"task.patch"),"whitespace_check":"passed","reverse_application_check":"passed","normal_index_unchanged":True},"remaining":["Correct the three findings","Owner/device appearance and motion/cost acceptance"],"not_performed":["Model fixes","Device attachment check/test","APK","Real authentication/purchase","Live mutation/deployment","Owner-process restart"]})
print(json.dumps({"checkpoint":commit,"findings":len(findings),"unchanged_model_hashes":len(hashes),"renderers":list(metrics)},indent=2))
