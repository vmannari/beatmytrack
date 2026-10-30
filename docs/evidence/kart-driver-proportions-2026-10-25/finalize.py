"""Record measured kart proportions, native review and an isolated scoped checkpoint."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

EV = Path(__file__).resolve().parent
ROOT = EV.parents[2]
BEFORE = EV / "before"
ASSETS = Path("game/assets/vehicles/kart_refined_v1")
DOC = Path("docs/KART_DRIVER_PROPORTIONS_2026_10_25.md")
TAG = "KART-DRIVER-PROPORTIONS-20261025"


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    Path(path).write_bytes((json.dumps(value, indent=2) + "\n").encode())


results = {name: read(EV / name / "report.json") for name in ["proportions", "fit", "model", "model-mobile", "retained", "native", "native-mobile", "art"]}
assert all(value["failures"] == 0 for value in results.values())
baseline = read(EV / "proportions-before/report.json")
assert baseline["checks"] == 24 and baseline["failures"] == 14
parser = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures", (EV / "parser.log").read_text(encoding="utf-8-sig"))
assert parser
assert "KART_TESTS: 42 checks, 0 failures" in (EV / "handling.log").read_text(encoding="utf-8-sig")
assert "49 actual model captures" in (EV / "liveries.log").read_text(encoding="utf-8-sig")
assert "NEWS PHOTO FRAMING: 1 cars, 0 failures" in (EV / "news.log").read_text(encoding="utf-8-sig")
invariants = read(EV / "invariants-before.json")
for relative, expected in invariants.items(): assert sha(ROOT / relative) == expected, relative
old_source = (BEFORE / "game/vehicle/kart_driver.gd").read_text()
source = (ROOT / "game/vehicle/kart_driver.gd").read_text()
assert old_source[old_source.index("static func arm_path"):old_source.index("static func build")] == source[source.index("static func arm_path"):source.index("static func build")]
assert old_source[old_source.index('\t\tvar boot:'):] == source[source.index('\t\tvar boot:'):]
manifest = read(ROOT / ASSETS / "manifest.json")
old_manifest = read(BEFORE / ASSETS / "manifest.json")
for field, name in [("driver_sha256", "kart_driver.gd"), ("helmet_sha256", "kart_helmet.gd"), ("model_sha256", "kart_model.gd"), ("geometry_sha256", "kart_geometry.gd")]:
    assert manifest[field] == sha(ROOT / "game/vehicle" / name)
keys = {item["file"] for item in manifest["meshes"]}
assert keys == {item["file"] for item in old_manifest["meshes"]}
assert keys == {p.name for p in (ROOT / ASSETS).glob("*.res")}
changed = [item for item in manifest["meshes"] if sha(ROOT / ASSETS / item["file"]) != sha(BEFORE / ASSETS / item["file"])]
assert len(changed) == 14
for index in range(1, 5):
    relative = Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{index}.res")
    assert sha(ROOT / relative) == sha(BEFORE / relative)
photos = sorted((ROOT / "game/assets/liveries/previews_v2/kart").glob("*.png"))
assert len(photos) == 49 and all(sha(p) != sha(BEFORE / p.relative_to(ROOT)) for p in photos)
before = baseline["measurements"]["full"]
after = results["proportions"]["measurements"]["full"]
shorter_percent = 100 * (1 - after["legs"][0]["length"] / before["legs"][0]["length"])


def strip(raw):
    return re.sub(rb"(?ms)^<!-- " + TAG.encode() + rb" -->\r?\n.*?^<!-- /" + TAG.encode() + rb" -->\r?\n(?:\r?\n)?", b"", raw)


def block(relative, text, append=False):
    path = ROOT / relative
    raw = strip(path.read_bytes())
    nl = b"\r\n" if b"\r\n" in raw else b"\n"
    addition = (f"<!-- {TAG} -->\n{text}\n<!-- /{TAG} -->\n\n").encode().replace(b"\n", nl)
    path.write_bytes(raw + nl + addition if append else addition + raw)


summary = (
    "## Kart seated leg/torso proportion correction (2026-10-25)\n"
    f"KDP01-KDP02/V02-V05/R01/G01/Q01: Owner rejects long legs relative to the torso. Forward hips and a reclined torso shorten actual trouser centre lines {shorter_percent:.2f}% (0.9663 to 0.7307 model metres), increase hip/shoulder span 0.2942 to 0.4165 and reduce leg/torso ratio 3.284 to 1.754. "
    "Knee bend grows 16.80 to 27.63 degrees; seat pan/back follow the hips and maintain zero cloth/shell crossings and the original support-gap tolerance. Helmet, collar, shoulders, arms, hands, boots, pedals, kart assembly, camera and canonical physics/config sources remain. "
    f"Proportions 24, fit 28, model 86 Compatibility/86 desktop Mobile, retained 172, Garage/race 15/15, kart 42 and parser {parser[1]} pass. Original 24-check/14-failure proportion regression is retained. "
    "Fourteen prepared meshes change; 216 remain byte-identical, with full/simple 94296/28894 triangles unchanged. Body shadow and catalogue/news/all 49 photos refreshed. Evidence/commands/scoped checkpoint: docs/KART_DRIVER_PROPORTIONS_2026_10_25.md and docs/evidence/kart-driver-proportions-2026-10-25/report.json. Reload and owner/device appearance/motion/cost acceptance remain. No device attachment check/test, APK, purchase, live mutation, deployment or owner-process restart; concurrent work preserved."
)
shared = [Path(p) for p in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "licenses/ASSETS.md"]]
for relative in shared[:3]: block(relative, summary)
block(shared[3], "## Original kart seated proportions revision\n2026-10-25: Original authored forward-hip/reclined torso, shortened continuous legs and supporting open bucket in kart_driver.gd. Native prepared geometry, body shadow and vehicle photos refreshed using existing materials. No external asset/model/image added. Evidence: docs/KART_DRIVER_PROPORTIONS_2026_10_25.md.", append=True)

doc = f"""# Kart driver proportions — 2026-10-25

The owner identifies legs that are unnaturally long compared with the torso. KDP01-KDP02 / V02-V05 / R01 / G01 / Q01 correct the seated proportions and preserve the preceding helmet and open-seat fixes.

The hips move forward by 0.25 model metres. A longer reclined waist/abdomen connects them to the existing chest and shoulders, while shorter thighs/shins bend below the steering wheel. The thin open bucket's pan and lumbar curve follow the new pelvis/back. The helmet, neck, collar, shoulders, arms, hands, boots and pedals keep their original positions; the complete kart assembly and production cameras retain their exact source hashes.

| Actual detailed mesh measurement | Before | Revised |
| --- | ---: | ---: |
| Trouser centre-line length | {before['legs'][0]['length']:.6f} | {after['legs'][0]['length']:.6f} |
| Hip-to-shoulder span | {before['torso_length']:.6f} | {after['torso_length']:.6f} |
| Leg/torso ratio | {before['legs'][0]['torso_ratio']:.3f} | {after['legs'][0]['torso_ratio']:.3f} |
| Knee bend, degrees | {before['legs'][0]['knee_bend_degrees']:.2f} | {after['legs'][0]['knee_bend_degrees']:.2f} |

Legs are **{shorter_percent:.2f}% shorter**. Measurements average actual baked cloth rings, omit the duplicate seam vertex, and interpolate the spine at hip/shoulder heights. They do not call the production authoring functions. The simpler model independently passes the same bounds with ratio 1.762. These are review bounds for the requested pose, not a universal anthropometric specification.

Native matched review:

- [Before side](evidence/kart-driver-proportions-2026-10-25/before-model/full-driver-side.png), [revised side](evidence/kart-driver-proportions-2026-10-25/model/full-driver-side.png).
- [Before front](evidence/kart-driver-proportions-2026-10-25/before-model/full-driver.png), [revised front](evidence/kart-driver-proportions-2026-10-25/model/full-driver.png), [seat from above](evidence/kart-driver-proportions-2026-10-25/model/full-seat-top.png).
- [Desktop Mobile/simple](evidence/kart-driver-proportions-2026-10-25/model-mobile/simple-driver.png), [actual Garage](evidence/kart-driver-proportions-2026-10-25/native/garage-1280.png), [actual race](evidence/kart-driver-proportions-2026-10-25/native/race.png).

Changed source files are game/vehicle/kart_driver.gd, game/tests/test_kart_driver_fit.gd and the new game/tests/test_kart_driver_proportions.gd. The existing fit fixture's rays follow the moved hips/backrest: hip z changes 0.20 to -0.04, and its 0.05-wide backrest window follows the new torso. Its open-cavity, pan-height, zero mesh-crossing and 0.004–0.035 torso-support-gap invariants remain. The actual back support gap is about 0.0157 model metres. No prior threshold is relaxed. The unchanged model and mechanical suites retain the helmet, watertightness, tyre, engine, exhaust, steering, sleeve and inlay checks.

Final results: **24** proportions, **28** fit, **86/86** Compatibility/desktop Mobile model, **172** retained mechanical checks, **15/15** actual Garage/race, **42** kart handling, and **{parser[1]}** parsed scripts, all with zero failures. The original prepared model is retained as a **24-check/14-failure** proportions regression; the authored draft passes on its first run. All 49 appearance images, catalogue image and newspaper photo are refreshed and imported. Full/simple visible triangles remain exactly **94,296/28,894**; the unchanged detailed cap is 95,000. Fourteen of 230 prepared mesh binaries change; **216 are byte-identical**. The body shadow has {manifest['shadows'][0]['triangles']} triangles, and all four wheel shadow binaries remain identical. No new material, shader, light, runtime callback or simulation change is introduced.

Actual commands use pinned Godot 4.7.2 through scripts/dev.ps1, with isolated APPDATA/LOCALAPPDATA under build/kart-driver-proportions. The local wrapper copies exact native logs and writes per-command parameters/exit codes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job before-model
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job proportions-before
foreach ($job in @('proportions-draft','fit-draft','draft','bake','proportions','fit','model','retained','art','liveries','news','import','native','handling','parser')) {{
    powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job $job
}}
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job model -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-proportions-2026-10-25/run.ps1 -Job native -Renderer mobile
python docs/evidence/kart-driver-proportions-2026-10-25/finalize.py
```

[report.json](evidence/kart-driver-proportions-2026-10-25/report.json) records commands, measurements, source/asset hashes and an isolated task-only Git checkpoint. Its binary patch passes whitespace and reverse-application checks with the repository's real .gitattributes; the normal index is untouched. Concurrent work is preserved.

Client reload and owner visual acceptance remain. No device attachment check/test, APK build/install, real authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan renderer test. Startup hitch logs remain recorded; this task makes no physical-device performance claim.
"""
(ROOT / DOC).write_bytes(doc.encode())

sources = [Path(p) for p in ["game/vehicle/kart_driver.gd", "game/vehicle/kart_driver.gd.uid", "game/tests/test_kart_driver_fit.gd", "game/tests/test_kart_driver_fit.gd.uid", "game/tests/test_kart_driver_proportions.gd", "game/tests/test_kart_driver_proportions.gd.uid"]]
files = sources + shared + [DOC, ASSETS / "manifest.json"] + [ASSETS / name for name in sorted(keys)]
files += [p.relative_to(ROOT) for p in photos] + [Path("game/assets/menu/kart_illustration_v1.png"), Path("game/assets/news/vehicles/kart.png")]
files += [Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res") for i in range(5)]
save(EV / "source-asset-hashes.json", {p.as_posix(): sha(ROOT / p) for p in files})
checkpoint = ROOT / "build/kart-driver-proportions/checkpoint"
assert not checkpoint.exists()
checkpoint.mkdir(parents=True)
index_hash = sha(ROOT / ".git/index")
env = {k: v for k, v in os.environ.items() if k not in ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"]}


def git(*args):
    return subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "user.name=Codex", "-c", "user.email=codex@local.invalid", "-C", str(checkpoint), *args], env=env, check=True, capture_output=True, text=True).stdout.strip()


def copy(source, relative):
    target = checkpoint / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)


git("init", "--quiet")
copy(ROOT / ".gitattributes", Path(".gitattributes"))
for p in BEFORE.rglob("*"):
    if p.is_file(): copy(p, p.relative_to(BEFORE))
for p in shared:
    target = checkpoint / p
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(strip((ROOT / p).read_bytes()))
git("add", "--all")
git("commit", "--quiet", "-m", "Exact task-start kart driver and current shared document baseline")
base = git("rev-parse", "HEAD")
for p in files: copy(ROOT / p, p)
git("add", "--all")
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "Rebalance kart leg and torso proportions with forward seated hips")
commit = git("rev-parse", "HEAD")
git("diff", "--binary", "--output=" + str(EV / "task.patch"), "HEAD~1", "HEAD")
git("apply", "--reverse", "--check", str(EV / "task.patch"))
assert not git("status", "--porcelain")
assert sha(ROOT / ".git/index") == index_hash
(EV / "checkpoint-stat.txt").write_bytes((git("show", "--stat", "--oneline", "HEAD") + "\n").encode())
save(EV / "report.json", {
    "date": "2026-10-25", "requirements": ["KDP01", "KDP02", "V02", "V03", "V04", "V05", "R01", "G01", "Q01"],
    "results": results, "original_proportions_regression": baseline, "parser_scripts": int(parser[1]), "kart_handling": {"checks": 42, "failures": 0},
    "leg_reduction_percent": shorter_percent, "prepared": {"resources": len(keys), "changed": changed, "byte_identical": len(keys)-len(changed), "shadows": manifest["shadows"], "wheel_shadow_binaries_unchanged": True},
    "unchanged_source_hashes": invariants, "unchanged_driver_sections": ["arm path and sleeve geometry", "boots/soles, arms/gloves and helmet assembly"],
    "art": {"appearance_photos": 49, "all_photo_hashes_changed": True, "news": read(EV / "news/framing.json"), "import_log": "import.log"},
    "desktop_startup_hitch_ms": {name: re.findall(r"RACE_HITCH frame_ms=([0-9.]+)", (EV / (name+".log")).read_text(encoding="utf-8-sig")) for name in ["native", "native-mobile"]},
    "commands": "run.ps1 and *-command.json", "hashes": "source-asset-hashes.json",
    "checkpoint": {"repository": str(checkpoint), "base": base, "commit": commit, "patch": "task.patch", "sha256": sha(EV / "task.patch"), "whitespace_check": "passed", "reverse_application_check": "passed", "normal_index_unchanged": True},
    "remaining": ["Client reload", "Owner appearance review", "Physical-device appearance/motion/cost acceptance"],
    "not_performed": ["Device attachment check/test", "APK build/install", "Real authentication/purchase", "Live mutation/deployment", "Owner-process restart"]
})
print(json.dumps({"checkpoint": commit, "leg_reduction_percent": shorter_percent, "parser_scripts": int(parser[1]), "results": {name: value["checks"] for name, value in results.items()}}, indent=2))
