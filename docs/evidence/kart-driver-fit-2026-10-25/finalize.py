"""Record native results and create a task-scoped checkpoint outside the main index."""
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
TAG = "KART-DRIVER-FIT-20261025"
DOC = Path("docs/KART_DRIVER_FIT_2026_10_25.md")
ASSETS = Path("game/assets/vehicles/kart_refined_v1")


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


results = {}
for folder in ["model", "model-mobile", "fit", "fit-mobile", "retained", "native", "native-mobile", "art", "integrity"]:
    results[folder] = read(EV / folder / "report.json")
    assert results[folder]["failures"] == 0, folder
parser = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures", (EV / "parser.log").read_text(encoding="utf-8-sig"))
assert parser
assert "0 failures" in (EV / "handling.log").read_text(encoding="utf-8-sig")
assert "49 actual model captures" in (EV / "liveries.log").read_text(encoding="utf-8-sig")
assert "NEWS PHOTO FRAMING: 1 cars, 0 failures" in (EV / "news.log").read_text(encoding="utf-8-sig")
invariants = read(EV / "invariants-before.json")
for path, expected in invariants.items():
    assert sha(ROOT / path) == expected, path
old_model = (BEFORE / "game/vehicle/kart_model.gd").read_text()
model = (ROOT / "game/vehicle/kart_model.gd").read_text()
assert old_model[old_model.index("static func _body("):old_model.index("static func _limb(")] == model[model.index("static func _body("):model.index("static func _driver(")]
assert old_model[old_model.index("\t# Anatomically aligned hands"):].split("static func _engine(")[0] == model[model.index("\t# Anatomically aligned hands"):].split("static func _engine(")[0]
assert old_model[old_model.index("static func _engine("):] == model[model.index("static func _engine("):]
manifest = read(ROOT / ASSETS / "manifest.json")
old = read(BEFORE / ASSETS / "manifest.json")
for field, source in [("model_sha256", "kart_model.gd"), ("helmet_sha256", "kart_helmet.gd"), ("driver_sha256", "kart_driver.gd"), ("geometry_sha256", "kart_geometry.gd")]:
    assert manifest[field] == sha(ROOT / "game/vehicle" / source)
current = {entry["file"] for entry in manifest["meshes"]}
previous = {entry["file"] for entry in old["meshes"]}
assert current == {p.name for p in (ROOT / ASSETS).glob("*.res")}
identical = [name for name in current & previous if sha(ROOT / ASSETS / name) == sha(BEFORE / ASSETS / name)]
assert len(identical) == 178
for i in range(1, 5):
    rel = Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res")
    assert sha(ROOT / rel) == sha(BEFORE / rel)
photos = sorted((ROOT / "game/assets/liveries/previews_v2/kart").glob("*.png"))
assert len(photos) == 49
assert all(sha(p) != sha(BEFORE / p.relative_to(ROOT)) for p in photos)


def strip(raw):
    return re.sub(rb"(?ms)^<!-- " + TAG.encode() + rb" -->\r?\n.*?^<!-- /" + TAG.encode() + rb" -->\r?\n(?:\r?\n)?", b"", raw)


def block(relative, content, append=False):
    path = ROOT / relative
    raw = strip(path.read_bytes())
    newline = b"\r\n" if b"\r\n" in raw else b"\n"
    addition = (f"<!-- {TAG} -->\n{content}\n<!-- /{TAG} -->\n\n").encode().replace(b"\n", newline)
    path.write_bytes(raw + newline + addition if append else addition + raw)


summary = (
    "## Kart compact chin, driver and open seat correction (2026-10-25)\n"
    "KDF01-KDF03/V02-V05/R01/G01/Q01: Shorten/retract the rejected chin and lift its lower edge; "
    "shape continuous hips/waist/chest/shoulders, elbow sleeves and a connected balaclava neck. "
    "A thin watertight open bucket replaces the seat's closed solid volume, with pan/back padding and rolled returns. "
    "Actual cloth/seat crossings fall to zero in both detail levels; torso/backrest gap is 0.0197 model metres. "
    "Native model 86 Compatibility/86 desktop Mobile, fit 28/28, retained 172, actual Garage/race 15/15, kart 42 and parser "
    f"{parser[1]} pass. Full/simple 94296/28894 triangles remain within the unchanged 95000 limit. "
    "Catalogue/news/all 49 photos refreshed; exact kart config, canonical simulation, production cameras, chassis/engine/wheels/steering retained. "
    "Initial geometry/fixture/runner failures and original-source regression remain recorded. "
    "Evidence, commands, hashes and scoped checkpoint: docs/KART_DRIVER_FIT_2026_10_25.md and docs/evidence/kart-driver-fit-2026-10-25/report.json. "
    "Client reload and owner/device appearance/motion/cost acceptance remain. No device attachment check/test, APK, purchase, live mutation, deployment or owner-process restart; concurrent work preserved."
)
shared = [Path(p) for p in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "licenses/ASSETS.md"]]
for path in shared[:3]:
    block(path, summary)
block(shared[3], "## Original kart driver and seat revision\n2026-10-25: Original code-authored compact helmet chin, tailored driver and thin open bucket seat in kart_helmet.gd/kart_driver.gd. Native prepared meshes, shadows and 49 appearance/catalogue/news photographs use the established CompactFinish materials. No external model, image or logo added. Provenance and checks: docs/KART_DRIVER_FIT_2026_10_25.md.", append=True)

doc = f"""# Kart helmet, driver and seat fit — 2026-10-25

The owner rejects the still-long chin, asks for a better driver body and identifies the driver intersecting the seat. KDF01-KDF03 / V02-V05 / R01 / G01 / Q01 cover this presentation-only correction.

| Requirement | Result |
| --- | --- |
| KDF01 | Retract the lower chin profile by up to 0.052 model metres and lift its lowest point from 0.737 to 0.765. The actual front ray at y=0.815 meets the chin at z=0.01365. The round crown, real swept eye port, fitted visor and hardware remain. |
| KDF02 | One shaped suit surface follows hips, waist, chest and shoulders; continuous sleeves bend through the elbows, with trim sampled from the same cloth surface. Refined legs/gloves and a balaclava neck connect the seated figure to its helmet. Hands, steering assembly and boots retain their control locations. |
| KDF03 | Replace the closed seat volume with a thin, open bucket: curved pan, rising back, flared sides, 0.012-thick shell/returns and separate inset padding. The shell stays watertight while its occupied cavity is open above and in front. Actual torso/backrest gap is 0.01968 model metres. All 23,424 detailed and 5,856 simple cloth triangle edges clear the seat shell. |

The new kart_driver.gd owns the seat and driver surfaces. Kart model calls it before the existing steering assembly. The baked manifest pins its SHA-256 alongside the model, helmet and geometry sources. Mesh creation occurs offline; production uses immutable prepared geometry and the established opaque materials. No new per-frame callback, transparency pass, light or shader is added.

Native matched review images:

- [Before driver](evidence/kart-driver-fit-2026-10-25/before-model/full-driver.png), [revised driver](evidence/kart-driver-fit-2026-10-25/model/full-driver.png).
- [Before chin](evidence/kart-driver-fit-2026-10-25/before-model/full-helmet-side.png), [shortened chin](evidence/kart-driver-fit-2026-10-25/model/full-helmet-side.png).
- [Before seat/side](evidence/kart-driver-fit-2026-10-25/before-model/full-driver-side.png), [fitted side](evidence/kart-driver-fit-2026-10-25/model/full-driver-side.png), [open seat from above](evidence/kart-driver-fit-2026-10-25/model/full-seat-top.png).
- [Actual Garage](evidence/kart-driver-fit-2026-10-25/native/garage-1280.png), [actual driving view](evidence/kart-driver-fit-2026-10-25/native/race.png), [desktop Mobile driver](evidence/kart-driver-fit-2026-10-25/model-mobile/simple-driver.png).

Final native results: model **86/86** Compatibility/desktop Mobile, focused fit **28/28**, retained tyre/engine/exhaust/sleeve/inlay regression **172**, actual Garage/race **15/15**, kart handling **42**, parser **{parser[1]}** scripts with zero failures. Catalogue save, 49 appearance photographs, newspaper framing and asset import pass. Visible detailed/simple triangles are **94,296/28,894**, below the unchanged 95,000 limit. There are **230 prepared resources**; 178 are byte-identical, 18 existing keys change, 32 old keys retire and 34 new keys are added. The matching body shadow is 1,320 triangles; all four wheel shadows remain byte-identical. Restoring the kart model's original LF convention leaves all 235 prepared/shadow binaries unchanged; the exact-source/geometry integrity rerun passes **60** checks.

The original-source focused regression is retained in fit-before/ and its log. Its seat cuts through pelvis, torso and thighs, and its cavity rays strike solid material. Early authored review found trouser/seat contacts and an unsupported neck, which were corrected. The first pan lowering was 0.0024 below its retained support bound; raising the actual pan fixed that failure. The old helmet test used z<0 to locate its front edge; the shortened chin is now behind that plane, so the locator uses z<0.08 while retaining the original >0.07 front/rear-rise assertion and all aperture rays/budgets. No invariant or tolerance is weakened. Initial execution-policy/certificate-store failures, a partial-cache diagnostic and PowerShell log-capture mistakes are retained or described in report.json; final command receipts copy the runner's exact native logs.

Exact configuration hashes for all seven cars, shared simulation/handling, Garage/camera/game presentation sources and geometry helpers agree with task start. Within kart_model.gd, chassis/fairings, engine/exhaust/wheels and the complete steering assembly remain text-identical. This includes the accepted 140 km/h kart tune. Concurrent workspace changes are preserved.

Actual commands use pinned Godot 4.7.2 through scripts/dev.ps1, with disposable APPDATA/LOCALAPPDATA under build/kart-driver-fit and fixture records. run.ps1 records its parameters/exit codes and native logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job before-model
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job fit-before
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job bake
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job model
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job model -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job fit
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job fit -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job retained
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job art
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job liveries
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job news
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job import
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job native
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job native -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job handling
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-fit-2026-10-25/run.ps1 -Job parser
```

[report.json](evidence/kart-driver-fit-2026-10-25/report.json) lists results, hashes, retained failures and the isolated task-only Git checkpoint. The checkpoint compares exact task-start kart assets to the final files, with only this task's additions in shared documents. Its binary patch passes whitespace/reverse-application checks; the normal repository index is untouched.

Client reload and owner appearance review remain. Physical-device testing, attachment checking, APK build/install, real authentication/purchase, live mutation/deployment and owner-process restart were not performed. Desktop Mobile is a desktop renderer test. Native startup hitch logs remain; no device performance claim is made.
"""
(ROOT / DOC).write_bytes(doc.encode("utf-8"))

sources = [Path(p) for p in ["game/vehicle/kart_model.gd", "game/vehicle/kart_helmet.gd", "game/vehicle/kart_driver.gd", "game/tests/test_kart_model.gd", "game/tests/test_kart_driver_fit.gd", "game/tests/bake_kart_model.gd"]]
sources += [p.with_suffix(p.suffix + ".uid") for p in sources if (ROOT / p.with_suffix(p.suffix + ".uid")).exists()]
files = sources + [DOC] + shared + [ASSETS / "manifest.json"]
files += [ASSETS / name for name in sorted(current)] + [p.relative_to(ROOT) for p in photos]
files += [Path("game/assets/menu/kart_illustration_v1.png"), Path("game/assets/news/vehicles/kart.png")]
files += [Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res") for i in range(5)]
save(EV / "source-asset-hashes.json", {p.as_posix(): sha(ROOT / p) for p in files})

checkpoint = ROOT / "build/kart-driver-fit/checkpoint"
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
for path in BEFORE.rglob("*"):
    if path.is_file(): copy(path, path.relative_to(BEFORE))
for path in sources:
    if path.suffix == ".uid" and (BEFORE / str(path).removesuffix(".uid")).exists():
        copy(ROOT / path, path)
for path in shared:
    target = checkpoint / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(strip((ROOT / path).read_bytes()))
git("add", "--all")
git("commit", "--quiet", "-m", "Exact task-start kart and shared document baseline")
base = git("rev-parse", "HEAD")
for name in previous - current:
    path = (checkpoint / ASSETS / name).resolve()
    assert path.parent == (checkpoint / ASSETS).resolve()
    path.unlink()
for path in files: copy(ROOT / path, path)
git("add", "--all")
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "Shorten kart chin and rebuild driver with fitted open bucket seat")
commit = git("rev-parse", "HEAD")
git("diff", "--binary", "--output=" + str(EV / "task.patch"), "HEAD~1", "HEAD")
git("apply", "--reverse", "--check", str(EV / "task.patch"))
assert not git("status", "--porcelain")
assert index_hash == sha(ROOT / ".git/index")
(EV / "checkpoint-stat.txt").write_text(git("show", "--stat", "--oneline", "HEAD") + "\n", encoding="utf-8")
report = {
    "date": "2026-10-25", "requirements": ["KDF01", "KDF02", "KDF03", "V02", "V03", "V04", "V05", "R01", "G01", "Q01"],
    "results": results, "parser_scripts": int(parser[1]), "handling_log": "handling.log",
    "before_model": read(EV / "before-model/report.json"), "original_source_regression": read(EV / "fit-before/report.json"),
    "prepared": {"resources": len(current), "identical": len(identical), "changed_same_key": len(current & previous) - len(identical), "new": len(current - previous), "retired": len(previous - current), "shadows": manifest["shadows"], "wheel_shadows_identical": True},
    "unchanged_sources": invariants, "kart_model_text_identical_blocks": ["body/fairings/inlays", "steering assembly", "engine/exhaust/wheels"],
    "art": {"appearance_photos": len(photos), "all_photo_hashes_refreshed": True, "news_framing": read(EV / "news/framing.json"), "import_log": "import.log"},
    "initial_failures": ["First default execution hit PowerShell policy; process-local bypass used for the repository runner", "Sandbox native Windows root certificate store unavailable; native runs used approved Windows access", "Original unshortened chin test front locator z<0 no longer locates the retracted chin; locator updated and >0.07 rise assertion retained", "First driver had trouser/seat intersections and neck gap; corrected", "Lowered pan first sat below retained 0.24 support bound; actual pan raised", "Partial-cache diagnostic fit-partial-cache.log is not the original-source baseline", "Initial PowerShell Tee-Object missed Write-Host logs; final runner copies exact native log files", "Initial isolated checkpoint omitted repository .gitattributes and reported CRLF as trailing whitespace; exact policy copied into its baseline, model's LF restored and resource binaries verified unchanged"],
    "observed_desktop_startup_hitch_ms": {name: re.findall(r"RACE_HITCH frame_ms=([0-9.]+)", (EV / (name + ".log")).read_text(encoding="utf-8-sig")) for name in ["native", "native-mobile"]},
    "checkpoint": {"repository": str(checkpoint), "base": base, "commit": commit, "patch": "task.patch", "sha256": sha(EV / "task.patch"), "whitespace_check": "passed", "reverse_application_check": "passed", "normal_index_unchanged": True},
    "hashes": "source-asset-hashes.json", "commands": "run.ps1 and *-command.json receipts",
    "remaining": ["Client reload", "Owner appearance acceptance", "Physical-device appearance, motion and cost acceptance"],
    "not_performed": ["Device attachment check/test", "APK build/install", "Real authentication/purchase", "Live mutation/deployment", "Owner-process restart"]
}
save(EV / "report.json", report)
print(json.dumps({"checkpoint": commit, "parser": int(parser[1]), "resources": len(current), "results": {name: value["checks"] for name, value in results.items()}}, indent=2))
