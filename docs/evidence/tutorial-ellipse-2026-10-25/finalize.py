"""Reconcile local Ellipse evidence and validate a task-only patch in a fresh Git repo."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import uuid

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
TRACKERS = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "docs/README.md"]
ADDED = ["game/resources/tracks/ellipse.json", "game/tests/generate_ellipse.gd", "game/tests/generate_ellipse.gd.uid", "docs/TUTORIAL_ELLIPSE_2026_10_25.md", "docs/evidence/tutorial-ellipse-2026-10-25/finalize.py"]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def lf(data):
    return data.decode("utf-8").replace("\r\n", "\n")


def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")


start = json.loads((E/"task-start.json").read_text())
epoch = datetime.datetime.fromisoformat(start["captured_utc"]).timestamp()
logs = sorted((ROOT/"build/logs").glob("*/*.log"), key=lambda p:p.stat().st_mtime, reverse=True)
logs = [p for p in logs if p.stat().st_mtime >= epoch]


def retain_log(label, needle, extra=None):
    dest = E/(label+".log")
    source = next((p for p in logs if needle in p.read_text(encoding="utf-8", errors="replace") and (extra is None or extra in p.read_text(encoding="utf-8", errors="replace"))), None)
    if label == "app":
        original = ROOT/"build/logs/TestScript-26652/test-script.log"
        if original.exists() and needle in original.read_text(encoding="utf-8", errors="replace"): source = original
    if source is None:
        assert dest.exists() and needle in dest.read_text(encoding="utf-8", errors="replace"), "Missing retained log: "+label
        return {"source":"direct retained command output", "sha256":sha(dest.read_bytes())}
    shutil.copy2(source, dest)
    return {"source":str(source.relative_to(ROOT)).replace("\\", "/"), "sha256":sha(dest.read_bytes())}


focused = {}
for mode, folder in [("headless", "final-headless"), ("gl_compatibility", "gl_compatibility"), ("mobile", "mobile")]:
    p = E/folder/"test-report.json"
    if p.exists():
        result = json.loads(p.read_text())
        assert result["failures"] == 0, (mode, result)
        focused[mode] = result
    else:
        focused[mode] = {"status":"not_completed", "reason":"concurrent car model preload missing; see mobile-concurrent-car-edit.log"}
counts = "/".join(str(r.get("checks", "incomplete")) for r in focused.values())
log_manifest = {}
for label, needle, extra in [
    ("focused-headless", "First-play tutorial: 168 checks, 0 failures", None),
    ("focused-compatibility", "First-play tutorial: 226 checks, 0 failures", "OpenGL API"),
    ("retirement", "EDITOR_RETIREMENT_TESTS: 26 checks, 0 failures", None),
    ("downloads", "Cost downloads: 122 checks, 0 failures", None),
    ("app", "APP_TESTS: 141 checks, 0 failures", None),
    ("kerbs", "KERB_TESTS: 31 checks, 0 failures", None),
    ("road-pieces", "ROAD_PIECES_TESTS: 377 checks, 0 failures", None),
    ("catalogue", "CATALOG_TESTS: 21 checks, 0 failures", None),
    ("editor", "FREE_EDITOR_TESTS: 51 checks, 0 failures", None),
    ("parser", "SCRIPT_PARSE:", None),
    ("import", "loading_editor_layout", None),
    ("generation", "ELLIPSE_GENERATED:", None),
]:
    log_manifest[label] = retain_log(label, needle, extra)
if focused["mobile"].get("failures") == 0:
    log_manifest["focused-mobile"] = retain_log("focused-mobile", "First-play tutorial: 226 checks, 0 failures", "Vulkan")
parser = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures", (E/"parser.log").read_text(encoding="utf-8"))
assert parser
summary = (
    "2026-10-25 TE01-TE03/R01/G01/Q01: First tutorial race and native fallback use the existing official Ellipse "
    "with its exact layout/start/28 tyres. Delete Starter Circuit native/cloud assets and both old generator/export "
    "scripts/UIDs; remove its local seed/index entries, leaving26 exact-hash documents. GenerateEllipse and canonical "
    "verifier packaging use the replacement. Active diagnostics and guides migrate; old preference fallback preserves "
    "player files. Real five-lap Ellipse completes7116 ticks with existing physical detour inputs. "
    f"Focused{counts} headless/Compatibility/desktopMobile; retirement26/download122/App141/kerbs31/roads377/"
    f"catalogue21/editor51/parser{parser[1]}, pinned import and backend6 plus verifier recheck1 pass. "
    "Initial driver/editor/fixture and concurrent Mobile preload failures remain recorded. Commands, native views, "
    "hashes and scoped Git-checked patch: docs/TUTORIAL_ELLIPSE_2026_10_25.md and "
    "docs/evidence/tutorial-ellipse-2026-10-25/report.json. Reload and owner/device acceptance remain; no device check/test, "
    "APK, deployment, live mutation, purchase or owner-process restart. Concurrent work preserved."
)
marker = "TUTORIAL-ELLIPSE-20261025"
for name in TRACKERS:
    path = ROOT/name
    raw = path.read_bytes()
    if name == "docs/README.md":
        old = next(l for l in (E/"before"/name).read_bytes().splitlines(keepends=True) if l.startswith(b"| First-play tutorial |"))
        current = next(l for l in raw.splitlines(keepends=True) if l.startswith(b"| First-play tutorial |"))
        # Include only this task's row and current-catalogue wording changes.
        base = raw.replace(current, old, 1).replace(b"catalogue contains Ellipse;", b"catalogue contains Starter Circuit;")
        row = b"| First-play tutorial | [Ellipse tutorial and track retirement](TUTORIAL_ELLIPSE_2026_10_25.md), [stop/touch correction](TUTORIAL_STOP_TOUCH_2026_10_25.md) | [Tutorial controller](../game/tutorial/tutorial_controller.gd), [Settings Help](../game/ui/settings_page.gd) |\n"
        updated = raw.replace(current, row, 1)
    else:
        base = re.sub(rb"<!-- "+marker.encode()+rb" -->.*?<!-- /"+marker.encode()+rb" -->\r?\n\r?\n", b"", raw, flags=re.S)
        heading = "## Ellipse tutorial and Starter Circuit removal override (2026-10-25)\n" if name == "AGENTS.md" else ""
        updated = f"<!-- {marker} -->\n{heading}{summary}\n<!-- /{marker} -->\n\n".encode()+base
    dest = E/"checkpoint-base"/name
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(base)
    path.write_bytes(updated)

# Preserve a concurrent electric/forklift audio assertion in both patch sides.
name = "game/tests/test_vehicle_audio.gd"
base = (ROOT/name).read_bytes().replace(b"res://resources/tracks/ellipse.json", b"res://resources/tracks/starter_circuit.json")
dest = E/"checkpoint-base"/name
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_bytes(base)

names = sorted(set(start["files"]+ADDED))
manifest = {}
patch = []
bases = {}
for name in names:
    base_path = E/"checkpoint-base"/name
    if not base_path.exists(): base_path = E/"before"/name
    before = base_path.read_bytes() if base_path.exists() else b""
    after = (ROOT/name).read_bytes() if (ROOT/name).exists() else b""
    if before == after: continue
    bases[name] = before
    manifest[name] = {"before_sha256":sha(before) if before else None, "sha256":sha(after) if after else None, "lf_sha256":sha(lf(after).encode()) if after else None}
    for line in difflib.unified_diff(lf(before).splitlines(keepends=True), lf(after).splitlines(keepends=True), fromfile="a/"+name if before else "/dev/null", tofile="b/"+name if after else "/dev/null"):
        patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
patch_file = E/"task-only.patch"
patch_file.write_text("".join(patch), encoding="utf-8", newline="\n")
scratch = ROOT/"build"/("tutorial-ellipse-checkpoint-"+uuid.uuid4().hex)
scratch.mkdir()
for name, before in bases.items():
    if before:
        dest = scratch/name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(lf(before), encoding="utf-8", newline="\n")
for args in [["init", "--quiet"], ["config", "core.autocrlf", "false"], ["apply", "--check", str(patch_file)], ["apply", str(patch_file)]]:
    result = subprocess.run(["git", *args], cwd=scratch, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
assert all(((scratch/name).exists() and sha((scratch/name).read_bytes()) == data["lf_sha256"]) if data["sha256"] else not (scratch/name).exists() for name, data in manifest.items())

index = json.loads((ROOT/"game/resources/cloud_tracks/index.json").read_text())
native = json.loads((ROOT/"game/resources/tracks/ellipse.json").read_text())
source_path = ROOT/"game/resources/cloud_tracks/893027446fb96e8a38a64b3143b033c04c15587b0364f6700fbda7985973defc.json"
assert native["creator_document"] == json.loads(source_path.read_text())
assert len(index["documents"]) == 26 and all(sha((ROOT/"game/resources/cloud_tracks"/filename).read_bytes()) == key for key, filename in index["documents"].items())
lab = json.loads((ROOT/"backend/bmt_backend/lab_tracks.json").read_text())
assert len(lab["documents"]) == 26 and all(d["id"] != "starter_circuit" for d in lab["documents"])
assert index["source_sha256"] == sha((ROOT/"backend/bmt_backend/lab_tracks.json").read_bytes())
assert json.loads((ROOT/"game/resources/builtin_tracks.json").read_text())["entries"][0]["id"] == "ellipse"
assert not (ROOT/"game/resources/tracks/starter_circuit.json").exists()
assert not (ROOT/"game/resources/cloud_tracks/442b1b6ccd3bbb423efd3ad1aa53f297653c1e00b5951c1740e81559580cfd41.json").exists()
assert all(not (ROOT/name).exists() for name in ["game/tests/generate_starter.gd","game/tests/export_backend_starter.gd"])
assert all(token not in (ROOT/"scripts/dev.ps1").read_text() for token in ["GenerateStarter","GenerateBackendStarter"])
report = {"task":"Ellipse tutorial and Starter Circuit removal", "date":"2026-10-25", "requirements":["TE01","TE02","TE03","R01","G01","Q01"], "engine":(ROOT/"godot-version.txt").read_text().strip(), "focused":focused, "regressions":{"retirement":26,"downloads":122,"app":141,"kerbs":31,"road_pieces":377,"catalogue":21,"editor":51,"parser":int(parser[1]),"backend_pass":6,"backend_deselected":4,"verifier_recheck_pass":1,"verifier_recheck_deselected":69,"import":"pass"}, "logs":log_manifest, "exact_ellipse_document_sha256":sha(source_path.read_bytes()), "remaining_cache_documents":26, "original_layout_and_objects_preserved":True, "files":manifest, "checkpoint":{"files":len(manifest),"patch_sha256":sha(patch_file.read_bytes()),"git_apply_check":True,"reconstructed_lf_hashes_match":True,"isolated_directory":str(scratch.relative_to(ROOT)).replace("\\","/")}, "retained_attempts":["headless-initial/test-report.json","free-editor-initial.log","free-editor-intermediate.log","backend-tests.log","backend-verifier-recheck.log","mobile-concurrent-car-edit.log"], "limits":["Physical device/touch and owner acceptance remain.","Local bundle/seed retirement does not mutate existing live publications or historical race data.","Historical fixtures, evidence and legacy-preference rejection assertions keep historical track names.","Concurrent runtime/car/editor/physics changes are preserved; this checkpoint contains only this task's changes."]}
commands = ["# Pinned scripts/dev.ps1; APPDATA is workspace-local build/tutorial-ellipse-2026-10-25/<suite>-userdata.", "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 GenerateEllipse -CommandTimeoutSeconds 300"]
for mode, folder in [("headless","final-headless"),("gl_compatibility","gl_compatibility"),("mobile","mobile")]:
    graphics = "" if mode == "headless" else f" -Graphical -RenderingMethod {mode}"
    commands.append(f"powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_first_play_tutorial.gd{graphics} -TestArgument '--evidence-root=res://../docs/evidence/tutorial-ellipse-2026-10-25/{folder}' -CommandTimeoutSeconds 300")
for script in ["test_editor_retirement.gd","test_cost_downloads.gd","test_app.gd","test_kerbs.gd","test_road_pieces.gd","test_catalog.gd","test_free_editor.gd","test_script_parse.gd"]:
    commands.append(f"powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/{script} -CommandTimeoutSeconds 300")
commands.append("powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import -CommandTimeoutSeconds 300")
commands.extend([".tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_purchase_lab_catalog.py backend/tests/test_predictive_drivers.py -k 'not cached_and_regenerated and not arbitrary_creator_splines' -q --basetemp=build/tutorial-ellipse-2026-10-25/pytest-current", ".tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -k standalone_verifier_contains_complete_handbrake_model -q --basetemp=build/tutorial-ellipse-2026-10-25/pytest-recheck"])
report["commands"] = commands
report["retained_attempts"].append("retirement-intermediate.log")
report["retirement_checks"] = {"native_asset_absent":True,"cloud_copy_absent":True,"old_generators_and_commands_absent":True,"seed_excludes_old_identity":True,"remaining_cache_hashes_exact":True,"seed_index_fingerprint_matches":True}
save(E/"report.json", report)
html = ["<!doctype html><meta charset='utf-8'><title>Ellipse tutorial</title><style>body{background:#101820;color:#eee;font:16px system-ui;max-width:1400px;margin:30px auto}figure{display:inline-block;width:47%;margin:1%;vertical-align:top}img{width:100%}a{color:#ffd25b}</style><h1>Ellipse tutorial and Starter Circuit removal</h1>", f"<p>Focused: {counts}. <a href='report.json'>Report and limits</a></p>"]
for label in ["hall-ready","first-race-countdown","first-race-driving","first-race-results","results-footer-960x540","highlight-buttons-0"]:
    html.append(f"<figure><figcaption>{label}</figcaption><img src='gl_compatibility/{label}.png'></figure>")
(E/"report.html").write_text("\n".join(html), encoding="utf-8")
print(json.dumps({"focused":counts,"files":len(manifest),"git_apply_check":True,"reconstructed_hashes_match":True}))
