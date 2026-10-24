"""Collect completed native coverage checks and publish a scoped checkpoint."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
PREFIX = E.relative_to(ROOT).as_posix()
BASE = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1"


def log(name):
    data = (E / (name + ".log")).read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig")


tests = []
for name, script, renderer, timeout, action in [
    ("places-headless", "test_desert_sand_places", "", 240, "TestScript"),
    ("places-mobile", "test_desert_sand_places", "mobile", 300, "TestScript"),
    ("places-compatibility", "test_desert_sand_places", "gl_compatibility", 300, "TestScript"),
    ("wind-headless", "test_desert_sand_wind", "", 180, "TestScript"),
    ("wind-mobile", "test_desert_sand_wind", "mobile", 300, "TestScript"),
    ("wind-compatibility", "test_desert_sand_wind", "gl_compatibility", 300, "TestScript"),
    ("ambience-headless", "test_desert_ambience", "", 180, "TestScript"),
    ("biomes-headless", "", "", 180, "TestBiomes"),
    ("parser", "test_script_parse", "", 240, "TestScript"),
]:
    result = re.findall(r"([A-Z_]+): (\d+) (checks|scripts), (\d+) failures", log(name))[-1]
    assert result[3] == "0", (name, result)
    command = BASE + " -Action " + action
    if script: command += " -ScriptPath res://tests/" + script + ".gd"
    if renderer: command += " -Graphical -RenderingMethod " + renderer
    if name.startswith("wind-") and renderer: command += " -TestArgument '--evidence=res://../" + PREFIX + "/focused'"
    command += " -CommandTimeoutSeconds " + str(timeout)
    tests.append(dict(log=name + ".log", command=command, checks=int(result[1]), failures=0))

native = {}
for renderer, name in [("mobile", "wind-mobile"), ("gl_compatibility", "wind-compatibility")]:
    row = json.loads((E / renderer / "coverage-prepared.json").read_text())
    row["race"] = json.loads((E / renderer / "race.json").read_text())
    row["palette"] = json.loads((E / "focused" / renderer / "palette.json").read_text())
    row["bursts"] = json.loads((E / "focused" / renderer / "timeline.json").read_text())
    roof = re.search(r"SAND_OPAQUE_SAMPLES: (\d+) changed=(\d+)", log(name))
    row["roof"] = dict(pixels=int(roof[1]), changed=int(roof[2]))
    key = "places-mobile" if renderer == "mobile" else "places-compatibility"
    row["added_pixels"] = int(re.search(r"SAND_PLACES_NATIVE: added_pixels=(\d+)", log(key))[1])
    sync = json.loads((E / renderer / "sync.json").read_text())
    row["audio_sync"] = {key:value for key,value in sync.items() if key != "samples"}
    row["artifact_hashes"] = {filename:hashlib.sha256((E/renderer/filename).read_bytes()).hexdigest() for filename in ["places-before.png","places-after.png","sand-in-race.png","wind-sync.wav","sync.json","race.json","coverage-prepared.json"]}
    native[renderer] = row
preserved = []
for item in json.loads((E / "unchanged-before.json").read_text(encoding="utf-8-sig")):
    path = Path(item["Path"])
    after = hashlib.sha256(path.read_bytes()).hexdigest()
    assert after.lower() == item["Hash"].lower(), path
    preserved.append(dict(path=path.relative_to(ROOT).as_posix(), sha256=after))
sample = native["mobile"]
doc_path = "docs/DESERT_SAND_PLACES_2026_10_24.md"
doc = f'''# Sand at more dune edges — 2026-10-24

DSP01 expands the number of nearby dune-edge emission sites. DSP02 preserves the accepted terrain hue, soft streams and wind-sound synchronization. DSP03/R01/G01/Q01 cover bounds, valid texture roots, bridges/banks, scenery, lifecycle and canonical isolation.

The active source limit is twelve instead of six (96 quads/192 triangles in the existing one-draw MultiMesh). Minimum source separation is five metres instead of eight, and placement updates at seven-metre cells instead of fourteen. All eligible traced-edge candidates are considered; the previous extra 15% random rejection is removed. Existing per-edge seed variation, local burst timing, wind/lift history, shader, opacity, palette, dune guides and ground/bridge exclusion stay exact. The coverage request intentionally changes the site-count/separation budgets; visual and canonical thresholds are retained.

The original selector is retained as an executable control. Across eighty route positions with real prepared ground support, nearby sites within 18 metres rise from {sample['before']} to {sample['after']} ({(sample['after']/sample['before']-1)*100:.1f}% more), and distinct readable-range locations from {sample['unique_before']} to {sample['unique_after']}. {sample['added_positions']}/80 positions have more nearby sites. The track-only control is 241 to 440 with additional sites at all eighty positions. A source-limit-only trial gave only 241 to 273; the closer placement/eligibility rules make the expanded pool useful. The first six-metre-spacing trial reached only 328, below the new 40% coverage guard; the final five-metre spacing passes it. Both initial logs remain.

## Actual checks

Pinned engine 4.7.2.stable.official.ed1daf0bf, desktop RTX 3090. Commands below were executed; logs and hashes are in [report.json](evidence/desert-sand-places-2026-10-24/report.json).

{chr(10).join('- `' + item['command'] + '` — ' + str(item['checks']) + ' ' + ('scripts' if item['log']=='parser.log' else 'checks') + ', 0 failures.' for item in tests)}

The new test extends the existing complete wind-sync, texture-edge and full-App regression. It checks the original/current spatial selectors on track-only and actual prepared geometry, source/discovery bounds, exact textured roots, retained sites, canonical state, original deformed prop arrays, cold/cached pyramids and normal App publication. The ordinary 50 km/h moving-camera test uses seeded ambience and identical-frame hidden/visible comparisons. Readable samples are {native['mobile']['race']['visible_samples']}/18 Mobile and {native['gl_compatibility']['race']['visible_samples']}/18 Compatibility; strict 2% contrast is {native['mobile']['race']['clear_samples']}/18 and {native['gl_compatibility']['race']['clear_samples']}/18. Same-camera/same-wind six/twelve-site native views show {native['mobile']['added_pixels']}/{native['gl_compatibility']['added_pixels']} changed pixels. All sampled roof pixels remain exact, with hue, low saturation, soft contrast and zero bright specks passing.

[Native preview with sound and before/after views](evidence/desert-sand-places-2026-10-24/preview.html). Sixteen-second recordings and actual JPG frames retain the Game-to-sand wind link through audio loop crossings. The browser check exercises audio play/seek, both renderer selections and both comparison images. No bitmap was generated or edited. Capturing frames/readbacks causes diagnostic hitch messages; these are not FPS measurements.

## Files and limits

Runtime changes are four parameter/selection edits in `game/track/desert_sand_wind.gd`. `game/tests/test_desert_sand_wind.gd` changes only the newly requested capacity and separation expectations; its appearance/occlusion/lifecycle/canonical assertions remain. `game/tests/test_desert_sand_places.gd` adds the spatial control and native comparison. This document, the three status files and evidence helpers complete the slice. The scoped checkpoint uses task-entry runtime/test snapshots; status snapshots are taken immediately before adding this task, preserving concurrent prefixes. The manifest verifies the shader, audio module, edge guides, support exclusion and Game source remain exact.

Discovery still stays below 8192 probes and 512 anchors per placement. The extra source slots and more frequent placement updates increase work; sustained phone/tablet preparation, fragment cost and appearance remain unmeasured. Owner recognition and balance on the affected track remain acceptance. Restart the development client to load this source. No phone/tablet attachment check or physical-device test, APK/export/install, native rebuild, live account/backend mutation or deployment was performed. Existing owner game/editor processes and concurrent work are preserved.
'''
(ROOT / doc_path).write_bytes(doc.encode())
status = f"2026-10-24 DSP01-DSP03/R01/G01/Q01: More Desert dune edges use twelve sites/96quads/192triangles, five-metre separation, seven-metre placement updates and all valid guides. Real prepared nearby-site coverage {sample['before']}to{sample['after']} ({(sample['after']/sample['before']-1)*100:.1f}%); distinct locations {sample['unique_before']}to{sample['unique_after']}, more sites at{sample['added_positions']}/80 route positions. Source-cap-only/spacing trials retained. Shader/palette, wind sync, guides/support and Game exact. Spatial/full-App {tests[0]['checks']}/{tests[1]['checks']}/{tests[2]['checks']}, focused {tests[3]['checks']}/{tests[4]['checks']}/{tests[5]['checks']}, ambience{tests[6]['checks']}, biomes{tests[7]['checks']} and parser{tests[8]['checks']} pass; roof pixels exact. Native audio/motion and six/twelve-site views, commands, hashes and scoped checkpoint: {doc_path} and {PREFIX}/report.json. Restart and owner/device appearance/cost acceptance remain. No device attachment check/test, APK, live mutation or deployment; concurrent work/owner processes preserved.\n\n"
status_paths = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for relative in status_paths:
    path = ROOT / relative
    marker = "## Broader Desert sand" if relative == "AGENTS.md" else "2026-10-24 DSP01"
    if not path.read_text(encoding="utf-8").startswith(marker):
        before = E / "before" / relative
        before.parent.mkdir(parents=True, exist_ok=True)
        before.write_bytes(path.read_bytes())
        heading = "## Broader Desert sand placement override (2026-10-24)\n" if relative == "AGENTS.md" else ""
        path.write_bytes((heading + status).encode() + path.read_bytes())
old_files = ["game/track/desert_sand_wind.gd", "game/tests/test_desert_sand_wind.gd"]
new_files = ["game/tests/test_desert_sand_places.gd", doc_path, PREFIX+"/before/game/track/desert_sand_wind.gd", PREFIX+"/build_preview.py", PREFIX+"/review_preview.py", PREFIX+"/finish_receipt.py", PREFIX+"/preview.html"]
paths = old_files + new_files + status_paths
patch, manifest = [], []
for relative in paths:
    path = ROOT / relative
    before = E / "before" / relative
    old = before.read_text(encoding="utf-8") if relative in old_files + status_paths else ""
    new = path.read_text(encoding="utf-8")
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    patch.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile="a/"+relative if old else "/dev/null", tofile="b/"+relative))
    manifest.append(dict(path=relative, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), before_sha256=hashlib.sha256(before.read_bytes()).hexdigest() if old else None))
    after = E / "after" / relative
    after.parent.mkdir(parents=True, exist_ok=True)
    after.write_bytes(path.read_bytes())
(E / "checkpoint.patch").write_bytes("".join(patch).encode())
git_checks = []
for command in (["git", "diff", "--check", "--"] + paths, ["git", "apply", "--reverse", "--check", str(E / "checkpoint.patch")]):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    git_checks.append(dict(command=command, exit_code=result.returncode, output=result.stdout+result.stderr))
    assert result.returncode == 0, git_checks[-1]
report = dict(date="2026-10-24", requirements=["DSP01","DSP02","DSP03","R01","G01","Q01"], engine="4.7.2.stable.official.ed1daf0bf", gpu="desktop RTX 3090", tests=tests, native=native, unchanged_files=preserved, changed_files=manifest, git_checks=git_checks,
              preview_review=json.loads((E/"preview-review.json").read_text()),
              offline_commands=["python docs/evidence/desert-sand-places-2026-10-24/build_preview.py", ".tools/review/Scripts/python.exe docs/evidence/desert-sand-places-2026-10-24/review_preview.py", "python docs/evidence/desert-sand-places-2026-10-24/finish_receipt.py"],
              limits=["Local source only; client restart required", "Owner affected-track appearance and device cost acceptance pending", "No device attachment check/test, APK, live mutation or deployment", "Concurrent work and owner processes preserved"])
(E/"report.json").write_bytes((json.dumps(report,indent=2)+"\n").encode())
print(json.dumps({"tests":len(tests),"failures":0,"git_checks":[x['exit_code'] for x in git_checks]}))
