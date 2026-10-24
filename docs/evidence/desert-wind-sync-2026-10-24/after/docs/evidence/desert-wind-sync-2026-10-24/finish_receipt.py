"""Publish the completed local Desert wind/sand evidence and scoped checkpoint."""
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
    raw = (E / (name + ".log")).read_bytes()
    return raw.decode("utf-16" if raw.startswith(b"\xff\xfe") else "utf-8-sig")


tests = []
for name, script, renderer, timeout, action in [
    ("sync-headless", "test_desert_wind_sync", "", 240, "TestScript"),
    ("sync-mobile", "test_desert_wind_sync", "mobile", 300, "TestScript"),
    ("sync-compatibility", "test_desert_wind_sync", "gl_compatibility", 300, "TestScript"),
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
    if script:
        command += " -ScriptPath res://tests/" + script + ".gd"
    if renderer:
        command += " -Graphical -RenderingMethod " + renderer
    if name.startswith("wind-") and renderer:
        command += " -TestArgument '--evidence=res://../" + PREFIX + "/focused'"
    command += " -CommandTimeoutSeconds " + str(timeout)
    tests.append(dict(log=name + ".log", command=command, checks=int(result[1]), failures=0))

native = {}
for renderer, name in [("mobile", "wind-mobile"), ("gl_compatibility", "wind-compatibility")]:
    native[renderer] = json.loads((E / renderer / "race.json").read_text())
    native[renderer]["palette"] = json.loads((E / "focused" / renderer / "palette.json").read_text())
    native[renderer]["local_bursts"] = json.loads((E / "focused" / renderer / "timeline.json").read_text())
    sync = json.loads((E / renderer / "sync.json").read_text())
    native[renderer]["audio_sync"] = {key:value for key,value in sync.items() if key != "samples"}
    roof = re.search(r"SAND_OPAQUE_SAMPLES: (\d+) changed=(\d+)", log(name))
    native[renderer]["roof"] = dict(pixels=int(roof[1]), changed=int(roof[2]))
cadence = re.search(r"WIND_SYNC_CADENCE: old=(\d+) new=(\d+)", log("sync-headless"))
old_rises, new_rises = int(cadence[1]), int(cadence[2])
doc_path = "docs/DESERT_WIND_SYNC_2026_10_24.md"
doc = f'''# More frequent sand with audible Desert gusts — 2026-10-24

DWS01 makes sand appear more often. DWS02 connects new sand at the texture lips to the selected wind recording and its broad gust envelope. DWS03/R01/G01/Q01 retain ordinary-driving readability, colour, gaps, occlusion, bounded work, scenery, canonical state and lifecycle fences.

The independent local periods are 2.4–4 seconds instead of 3.6–6, with no skipped local event (previously 10%). This is about 67% more nominal local starts. Shorter 1.1–1.65 second emissions keep clear intervals. The wind's first wait is 1–3 seconds; high/low holds are 1–3/1.5–4 seconds. Across twelve seeded 90-second runs the task-entry control has {old_rises} rising gusts and the final schedule has {new_rises} ({(new_rises/old_rises-1)*100:.1f}% more). The original 3.5–7 second smooth gust transitions, gains, three shuffled recordings and sound settings remain.

An offline 20 Hz circular guide follows a 350 ms loudness window in each unchanged mastered wind clip. Both WAV and OGG hashes are pinned. The active recording's playback cursor, random starting offset, mix interpolation and driver latency select the guide value. Driver latency is cached at reset/resume rather than queried per frame, following the [AudioServer guidance](https://docs.godotengine.org/en/stable/classes/class_audioserver.html#class-audioserver-method-get-output-latency); the cursor correction follows the [official audio synchronization method](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html). Muting sound still lets weather advance. There is no microphone, spectrum analyser, runtime decoding, new audio asset or new runtime dependency.

Game advances the existing Desert ambience first and passes its lift value into the sand in that same presentation frame. A fixed 48-sample/12 Hz history lets the shader look up the wind at each particle's birth time. Audible swells fill local emission gaps at the dune edges; airborne particles retain their own birth strength and drift away. Per-edge variation remains. No particle born before the weather starts is drawn. Finish uses the existing 0.6 second audio fade time. The original terrain colour/opacity, artwork coordinates, source exclusion, six sites, 48 quads/96 triangles, camera, lighting and scenery repair remain.

## Actual verification

Engine: pinned 4.7.2.stable.official.ed1daf0bf, desktop RTX 3090. All commands and logs are in [report.json](evidence/desert-wind-sync-2026-10-24/report.json).

{chr(10).join('- `' + item['command'] + '` — ' + str(item['checks']) + ' ' + ('scripts' if item['log']=='parser.log' else 'checks') + ', 0 failures.' for item in tests)}

`python scripts/bake_desert_wind_envelope.py --check` reproduces the guide exactly. The synchronization fixture compares the original schedule without its registered class name, checks all clip hashes and loop boundaries, verifies a short sound pulse moves through birth history, and covers pause/background/invalid input/retry. It then runs the complete texture-root, original-geometry, pyramid, cached-world and actual-App checks.

The native moving-camera test uses normal seeded ambience and a scripted 50 km/h path, with exact same-frame sand-hidden comparisons. Mobile is readable in {native['mobile']['visible_samples']}/18 samples (strict 2% contrast: {native['mobile']['clear_samples']}/18); Compatibility in {native['gl_compatibility']['visible_samples']}/18 (strict: {native['gl_compatibility']['clear_samples']}/18). Peaks are {native['mobile']['peak_pixels']}/{native['gl_compatibility']['peak_pixels']} perceptible pixels. Both renderers retain hue, low saturation, zero bright specks and {native['mobile']['roof']['pixels']} exact opaque roof pixels. No invariant or threshold was weakened.

[Play the native preview with recorded wind](evidence/desert-wind-sync-2026-10-24/preview.html). Each renderer has a 16 second recording from the actual wind/sand bus and native JPG frames on a shared timeline. Actual Game-to-sand lift values agree throughout, including loop crossings. `audio-analysis.json` includes an additional mixed-audio RMS correlation; it is diagnostic, not an acoustic timing certificate. Readback hitch messages in the capture fixtures are not FPS measurements.

## Corrections and scope

Initial generated packed-array constants were rejected by GDScript and replaced by constant plain arrays. The task-entry audio control required removing only its duplicate registered class declaration. An initial too-long local duration failed the existing quiet-gap invariant in Compatibility; shorter bursts and excluding pre-start births fixed it without weakening the assertion. That shorter trial reached only 8/18 strict-contrast Mobile samples; a square-root lift response makes quiet audible swells readable while retaining zero at silence and the same maximum. The isolated Mobile fixture then selected stale first-frame material state as its peak; flushing deferred reset/uploads before sampling corrected that capture and its dependent calm/detail/palette checks. Every threshold remains. Failed overlap/visibility/first-frame logs and initial native runs remain in evidence. Playwright's bundled browser was absent; the existing Edge installation passed without a download.

Runtime changes: `game/track/desert_ambience.gd`, `game/track/desert_sand_wind.gd`, its shader, new `game/track/desert_wind_envelope.gd`, and one Game call. New regression: `game/tests/test_desert_wind_sync.gd`. The existing edge fixture now directs its atlas to its selected evidence folder, preserving previous captures; `game/tests/test_desert_sand_wind.gd` flushes native reset/uploads before sampling. `scripts/bake_desert_wind_envelope.py` builds/checks the guide. This document, three status files and evidence helpers complete the slice. The checkpoint is built against task-entry runtime snapshots; status snapshots are refreshed immediately before inserting this task's entry so concurrent prefixes are preserved.

Owner recognition and balance on the affected track, plus sustained physical-device appearance/cost and acoustic timing, remain acceptance checks. Restart the development client to load this source. No phone/tablet attachment check or physical-device test, APK/export/install, native rebuild, live account/backend mutation or deployment was performed. Installed phone/tablet builds and existing owner game/editor processes were left alone.
'''
(ROOT / doc_path).write_bytes(doc.encode())
status = f"2026-10-24 DWS01-DWS03/R01/G01/Q01: More frequent local sand (2.4-4s periods) follows the selected wind recording's loudness/corrected playback cursor via bounded birth history, so gusts lift new grains at traced lips. Audible rising gusts {old_rises}to{new_rises} in twelve seeded90s controls; unchanged clips/gains, palette, six sites/48quads/96triangles and pyramid repair remain. Sync/App {tests[0]['checks']}/{tests[1]['checks']}/{tests[2]['checks']}, focused {tests[3]['checks']}/{tests[4]['checks']}/{tests[5]['checks']}, ambience{tests[6]['checks']}, biomes{tests[7]['checks']} and parser{tests[8]['checks']} pass. Actual driving readable samples {native['mobile']['visible_samples']}/18 Mobile/{native['gl_compatibility']['visible_samples']}/18 Compatibility; roof pixels exact. Initial parse/control/overlap corrections retained; no invariant weakened. Native audio preview, commands, hashes and scoped checkpoint: {doc_path} and {PREFIX}/report.json. Restart and owner/device appearance/cost/acoustic acceptance remain. No device attachment check/test, APK, live mutation or deployment; concurrent work and owner processes preserved.\n\n"
status_paths = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for relative in status_paths:
    path = ROOT / relative
    snapshot = E / "before" / relative
    marker = "## Audible Desert wind" if relative == "AGENTS.md" else "2026-10-24 DWS01"
    if not path.read_text(encoding="utf-8").startswith(marker):
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        snapshot.write_bytes(path.read_bytes())
        heading = "## Audible Desert wind and sand override (2026-10-24)\n" if relative == "AGENTS.md" else ""
        path.write_bytes((heading + status).encode() + path.read_bytes())

old_files = ["game/track/desert_ambience.gd", "game/track/desert_sand_wind.gd", "game/track/desert_sand_wind.gdshader", "game/core/game.gd", "game/tests/test_desert_dune_edges.gd", "game/tests/test_desert_sand_wind.gd"]
new_files = ["game/track/desert_wind_envelope.gd", "game/tests/test_desert_wind_sync.gd", "scripts/bake_desert_wind_envelope.py", doc_path, PREFIX+"/before/game/track/desert_ambience.gd", PREFIX+"/build_preview.py", PREFIX+"/review_preview.py", PREFIX+"/finish_receipt.py", PREFIX+"/preview.html"]
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
report = dict(date="2026-10-24", requirements=["DWS01","DWS02","DWS03","R01","G01","Q01"], engine="4.7.2.stable.official.ed1daf0bf", tests=tests, native=native,
              cadence=dict(old=old_rises,new=new_rises,seeded_runs=12,seconds_each=90), changed_files=manifest, git_checks=git_checks,
              audio_analysis=json.loads((E / "audio-analysis.json").read_text()),
              limits=["Local desktop source only; restart required", "Owner track/appearance acceptance pending", "No device attachment check or physical-device appearance/performance/acoustic test", "No APK, install, live mutation or deployment", "Concurrent work and owner processes preserved"],
              corrections=["Generated constant arrays corrected", "Duplicate class name removed only from the original schedule control", "Existing Compatibility quiet-gap failure fixed by shorter local duration and pre-start birth exclusion; threshold retained", "Short-burst Mobile strict-contrast8/18 corrected through a square-root audible-lift response; threshold retained"],
              preview_review=json.loads((E / "preview-review.json").read_text()),
              offline_commands=["python scripts/bake_desert_wind_envelope.py", "python scripts/bake_desert_wind_envelope.py --check", "python docs/evidence/desert-wind-sync-2026-10-24/build_preview.py", ".tools/review/Scripts/python.exe docs/evidence/desert-wind-sync-2026-10-24/review_preview.py", "python docs/evidence/desert-wind-sync-2026-10-24/finish_receipt.py"])
(E / "report.json").write_bytes((json.dumps(report,indent=2)+"\n").encode())
print(json.dumps({"tests":len(tests),"failures":0,"git_checks":[x['exit_code'] for x in git_checks]}))
