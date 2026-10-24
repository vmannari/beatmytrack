"""Record completed Winter source-only checks and an isolated Git checkpoint."""
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
    raw = (E/(name+".log")).read_bytes()
    return raw.decode("utf-16" if raw.startswith(b"\xff\xfe") else "utf-8-sig")


tests = []
for name, script, renderer, timeout, action in [
    ("edges-headless","test_winter_road_edge_snow","",240,"TestScript"),
    ("edges-mobile","test_winter_road_edge_snow","mobile",300,"TestScript"),
    ("edges-compatibility","test_winter_road_edge_snow","gl_compatibility",300,"TestScript"),
    ("winter-headless","test_winter_snow_wind","",240,"TestScript"),
    ("ground-headless","test_winter_ground_snow","",240,"TestScript"),
    ("biomes-headless","","",180,"TestBiomes"),
    ("parser","test_script_parse","",240,"TestScript"),
]:
    result = re.findall(r"([A-Z_]+): (\d+) (checks|scripts), (\d+) failures",log(name))[-1]
    assert result[3] == "0",(name,result)
    if renderer:
        command = 'powershell -NoProfile -ExecutionPolicy Bypass -Command "& \'./scripts/dev.ps1\' -Action TestScript -ScriptPath res://tests/'+script+'.gd -Graphical -RenderingMethod '+renderer+" -TestArgument @('--capture') -CommandTimeoutSeconds "+str(timeout)+'"'
    else:
        command = BASE+" -Action "+action
        if script: command += " -ScriptPath res://tests/"+script+".gd"
        command += " -CommandTimeoutSeconds "+str(timeout)
    tests.append(dict(log=name+".log",command=command,checks=int(result[1]),failures=0))
native = {}
for renderer,name in [("mobile","edges-mobile"),("gl_compatibility","edges-compatibility")]:
    native[renderer] = json.loads((E/renderer/"capture.json").read_text())
    del native[renderer]["frames"]
    native[renderer]["shape_comparison"] = [{"seconds":float(t),"maximum_rgb_error":float(delta)} for t,delta in re.findall(r"WINTER_WINDOW_DIFF: clock=([0-9.]+) maximum=([0-9.]+)",log(name))]
    assert len(native[renderer]["shape_comparison"]) == 7
    assert max(x["maximum_rgb_error"] for x in native[renderer]["shape_comparison"]) == 0.0
    native[renderer]["artifact_hashes"] = {file:hashlib.sha256((E/renderer/file).read_bytes()).hexdigest() for file in ["capture.json","before.png","after.png","without-snow.png"]}
preserved, concurrent = [], []
for item in json.loads((E/"unchanged-before.json").read_text(encoding="utf-8-sig")):
    path = Path(item["Path"])
    current = hashlib.sha256(path.read_bytes()).hexdigest()
    row = dict(path=path.relative_to(ROOT).as_posix(),before=item["Hash"].lower(),after=current)
    if current == row["before"]: preserved.append(row)
    else:
        assert row["path"] == "game/core/game.gd",row
        concurrent.append(row)
# The presentation integrator itself is unchanged; only source binding/setup is added.
wind_path = "game/track/winter_snow_wind.gd"
old_wind = (E/"before"/wind_path).read_text()
new_wind = (ROOT/wind_path).read_text()
present = lambda text:text.split("func present(")[1].split("func _bind_surfaces")[0]
assert present(old_wind) == present(new_wind)
doc_path = "docs/WINTER_ROAD_EDGE_SNOW_2026_10_24.md"
doc = f'''# Winter snow from road edges — 2026-10-24

WRE01 anchors snow-emission windows at the exposed upwind road boundary. WRE02 preserves the accepted effect: stream/grain shape, texture, colour, opacity, speeds, gust parameters, lighting, car protection and particle budgets. WRE03/R01/G01/Q01 cover world/curve alignment, lookup bounds, lifecycle, canonical data and native review.

The shipping effect is integrated into opaque road/snow materials, with a small airborne grain layer. Moving just the inactive fallback-card anchors would not change ordinary gameplay. A static wind-aligned source lookup now supplies actual road-entry positions to the existing shared local-window function. Each unchanged elliptical window is translated so its upwind tip begins at that boundary; grains and streams continue downwind using the existing field. The normal window radius/lifetime/speed calculations remain. The presentation integrator body is text-exact against task entry.

Source preparation uses the same authored road contours, 16 cm finish extension and spline surface tessellation as rendering. Scanline intervals are merged across road pieces, so internal joins do not become emitters. Current native grids without authored pieces use actual road-cell runs. Bridge-covered origins are omitted. The simulator/world-XZ side-axis sign is explicit. The single nearest-sampled float lookup is at most 512x512 (4 MiB); the native fixture is 96x16 (24 KiB) with ten road-edge origins. Large worlds coarsen lookup spacing. There is no per-frame road scan, extra particle population, new art, camera or audio change.

Private run-owned materials share the lookup; prepared materials retain their original defaults and the existing release/restore lifecycle. `winter-wind-17-road-edge-sources` and visual-kit214 invalidate cached flattened shaders so an old cached road cannot silently retain the old interface.

## Actual validation

Pinned engine 4.7.2.stable.official.ed1daf0bf; desktop RTX 3090. Logs, source hashes and checkpoint are in [report.json](evidence/winter-road-edge-snow-2026-10-24/report.json).

{chr(10).join('- `'+x['command']+'` — '+str(x['checks'])+(' scripts' if x['log']=='parser.log' else ' checks')+', 0 failures.' for x in tests)}

The source test checks every prepared origin against the exact road polygons, verifies outside/inside along the wind at straight and curved boundaries, enforces lookup bounds and compares authored content/cells/contact triangles byte-exactly. Existing lifecycle, 49/36 fallback layers, 48 airborne grains, 12/18 m/s motion, strengths, pause/background/retry/finish/biome isolation remain.

The native test runs the actual Winter Game. All run-owned opaque finishes share the correct lookup, and fallback cards remain disabled in the integrated path. A GPU comparison evaluates the task-original window and the relocated window at seven clocks over their matching support. All three output channels are pixel-exact (maximum error0) on both renderers. A separate positive-output check excludes an empty comparison. Ground/bank/air grain shaders, the flow bitmap and the wind audio controller are byte-exact against task entry.

Native normal-camera before/after captures change {native['mobile']['peak_changed']}/{native['gl_compatibility']['peak_changed']} pixels, while the relocated snow itself remains visible ({native['mobile']['snow_peak']}/{native['gl_compatibility']['snow_peak']} perceptible pixels in the sampled frames). At each of six clocks, every sampled opaque car-roof pixel is exact. A visibility toggle restores exact frozen snow pixels; simulation snapshots remain unchanged.

[Native motion and before/after preview](evidence/winter-road-edge-snow-2026-10-24/preview.html). Both renderer selections, three comparison states and seeking are checked in the existing Edge browser. Captures are actual Godot output, without image editing. Readback hitch diagnostics are not FPS measurements.

## Corrections, files and acceptance

The first capture launch exposed PowerShell's single-flag array binding; an explicit argument array fixes it. The first GPU reference used a compile-time constant random key and differed at one clock; feeding both functions the same runtime key yields zero error without changing the effect or threshold. Initial logs remain. A concurrent Game tutorial/rewind change is preserved and excluded from this task's patch.

Runtime files: `game/track/winter_road_snow_sources.gd`, source binding/version in `game/track/winter_snow_wind.gd`, source relocation in `game/track/winter_wind_variation.gdshaderinc`, and only the cache version in `game/track/native_track_visual.gd`. `game/tests/test_winter_road_edge_snow.gd` provides focused verification. This document, three status entries and scoped evidence helpers complete the slice. No existing invariant was weakened. The scoped checkpoint uses task-entry snapshots; status snapshots are refreshed immediately before publication to preserve concurrent prefixes.

Owner recognition on the affected track and sustained phone/tablet appearance/GPU sampling cost remain acceptance checks. Source placement necessarily changes which places emit; the effect's rendering/motion controls remain. No phone/tablet attachment check or physical-device test, APK/export/install, native rebuild, live account/backend mutation, deployment or owner-process restart was performed. Reload the development client to load the new shader/cache interface. Concurrent work and existing owner processes remain intact.
'''
(ROOT/doc_path).write_bytes(doc.encode())
status = f"2026-10-24 WRE01-WRE03/R01/G01/Q01: Winter's existing surface/air snow starts at exposed upwind road edges through one bounded static lookup; rendered contours/joins, curves and native-grid roads supply origins, with bridge exclusion. Same window/grain appearance, strengths, speed, wind audio and budgets; presentation integrator exact. Source checks{tests[0]['checks']}, native{tests[1]['checks']}/{tests[2]['checks']}, existing Winter{tests[3]['checks']}/ground{tests[4]['checks']}, biomes{tests[5]['checks']} and parser{tests[6]['checks']} pass. Seven GPU window comparisons per renderer are pixel-exact after relocation; actual visible snow and roof/canonical guards pass. Cache kit214/Winter17, initial launch/reference corrections and concurrent Game edit retained. Native preview, commands, hashes and task-only checkpoint: {doc_path} and {PREFIX}/report.json. Reload and owner/device appearance/sampling-cost acceptance remain. No attachment/device test, APK, live mutation, deployment or owner-process restart; concurrent work preserved.\n\n"
status_paths = ["AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md"]
for relative in status_paths:
    path = ROOT/relative
    marker = "## Winter road-edge snow" if relative == "AGENTS.md" else "2026-10-24 WRE01"
    if not path.read_text(encoding="utf-8").startswith(marker):
        snapshot = E/"before"/relative
        snapshot.parent.mkdir(parents=True,exist_ok=True); snapshot.write_bytes(path.read_bytes())
        heading = "## Winter road-edge snow sources override (2026-10-24)\n" if relative == "AGENTS.md" else ""
        path.write_bytes((heading+status).encode()+path.read_bytes())
old_files = [wind_path,"game/track/winter_wind_variation.gdshaderinc","game/track/native_track_visual.gd"]
new_files = ["game/track/winter_road_snow_sources.gd","game/tests/test_winter_road_edge_snow.gd",doc_path,PREFIX+"/before/game/track/winter_wind_variation.gdshaderinc",PREFIX+"/build_preview.py",PREFIX+"/review_preview.py",PREFIX+"/finish_receipt.py",PREFIX+"/preview.html"]
paths = old_files+new_files+status_paths
patch,manifest = [],[]
for relative in paths:
    path = ROOT/relative; before = E/"before"/relative
    old = before.read_text(encoding="utf-8") if relative in old_files+status_paths else ""
    new = path.read_text(encoding="utf-8")
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    patch.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile="a/"+relative if old else "/dev/null",tofile="b/"+relative))
    manifest.append(dict(path=relative,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),before_sha256=hashlib.sha256(before.read_bytes()).hexdigest() if old else None))
    after = E/"after"/relative; after.parent.mkdir(parents=True,exist_ok=True); after.write_bytes(path.read_bytes())
(E/"checkpoint.patch").write_bytes("".join(patch).encode())
git_checks = []
for command in (["git","diff","--check","--"]+paths,["git","apply","--reverse","--check",str(E/"checkpoint.patch")]):
    result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    git_checks.append(dict(command=command,exit_code=result.returncode,output=result.stdout+result.stderr))
    assert result.returncode == 0,git_checks[-1]
report = dict(date="2026-10-24",requirements=["WRE01","WRE02","WRE03","R01","G01","Q01"],tests=tests,native=native,unchanged=preserved,concurrent_changes=concurrent,changed_files=manifest,git_checks=git_checks,preview_review=json.loads((E/"preview-review.json").read_text()),
              offline_commands=["python docs/evidence/winter-road-edge-snow-2026-10-24/build_preview.py",".tools/review/Scripts/python.exe docs/evidence/winter-road-edge-snow-2026-10-24/review_preview.py","python docs/evidence/winter-road-edge-snow-2026-10-24/finish_receipt.py"],
              limits=["Local source; reload required","Owner track appearance and physical-device cost remain acceptance","No attachment/device test, APK, live mutation, deployment or owner-process restart","Concurrent Game changes retained"])
(E/"report.json").write_bytes((json.dumps(report,indent=2)+"\n").encode())
print(json.dumps(dict(tests=len(tests),failures=0,git_checks=[x['exit_code'] for x in git_checks])))
