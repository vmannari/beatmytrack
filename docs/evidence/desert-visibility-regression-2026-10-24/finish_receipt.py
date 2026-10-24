"""Build the task-scoped receipt from actual retained logs and native captures."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
E = Path(__file__).resolve().parent
BASE = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1"
tests = []

def test(log, script=None, rendering=None, action="TestScript", timeout=300, focused=False):
    command = f"{BASE} -Action {action}"
    if script:
        command += f" -ScriptPath res://tests/{script}.gd"
    if rendering:
        command += f" -Graphical -RenderingMethod {rendering}"
    if focused and rendering:
        command += " -TestArgument '--evidence=res://../docs/evidence/desert-visibility-regression-2026-10-24/focused'"
    command += f" -CommandTimeoutSeconds {timeout}"
    raw = (E / log).read_bytes()
    content = raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
    result = re.findall(r"([A-Z_]+): (\d+) (checks|scripts), (\d+) failures", content)[-1]
    row = dict(log=log, command=command, name=result[0], checks=int(result[1]), failures=int(result[3]))
    assert row["failures"] == 0, row
    tests.append(row)

test("app-headless.log", "test_desert_visibility_regression", timeout=240)
test("app-mobile.log", "test_desert_visibility_regression", "mobile")
test("app-compatibility.log", "test_desert_visibility_regression", "gl_compatibility")
test("wind-headless.log", "test_desert_sand_wind", timeout=180)
test("wind-mobile.log", "test_desert_sand_wind", "mobile", focused=True)
test("wind-compatibility.log", "test_desert_sand_wind", "gl_compatibility", focused=True)
test("chunks-headless.log", "test_cooperative_mesh_chunks", timeout=180)
test("egypt-headless.log", "test_egypt_props", timeout=180)
test("geometry-headless.log", "test_race_install_geometry")
test("desert-headless.log", action="TestDesert", timeout=180)
test("biomes-headless.log", action="TestBiomes", timeout=180)
test("app-suite.log", action="TestApp", timeout=180)
test("parser.log", "test_script_parse", timeout=240)

renderers = {}
for renderer in ("mobile", "gl_compatibility"):
    renderers[renderer] = json.loads((E / renderer / "race.json").read_text())
    renderers[renderer]["palette"] = json.loads((E / "focused" / renderer / "palette.json").read_text())

runtime = [f"game/track/{name}" for name in (
    "native_track_visual.gd", "desert_road_relief.gd", "spatial_mesh_chunks.gd",
    "desert_sand_wind.gd", "desert_sand_wind.gdshader")]
wind_test = "game/tests/test_desert_sand_wind.gd"
original_wind_test = (ROOT / wind_test).read_text().replace(
    '\tfor argument: String in OS.get_cmdline_user_args():\n\t\tif argument.begins_with("--evidence="): out = argument.trim_prefix("--evidence=").trim_suffix("/") + "/"\n', "")
if not (E / "before" / "test_desert_sand_wind.gd").exists():
    (E / "before" / "test_desert_sand_wind.gd").write_text(original_wind_test, encoding="utf-8")

doc = "docs/DESERT_VISIBILITY_REGRESSION_2026_10_24.md"
table = "\n".join(f"| {row['log']} | {row['checks']} | {row['failures']} |" for row in tests)
description = f"""# Desert scenery and wind visibility — 2026-10-24

Requirements: DVR01 restore missing Egyptian scenery; DVR02 make ordinary wind readable while driving; DVR03 verify the actual App's cold/cached race path; R01 canonical isolation; G01 native visual evidence; Q01 scoped checkpoint.

## Confirmed regression and repair

Desert relief subdivided the Egyptian family from 79,098 to 89,883 draw corners, leaving `spatial_object_ends` at 79,098. Subsequent spatial preparation detached that family and could fail on the invalid range, losing pyramids and other Egyptian props. The task-original valid-document control fails the exact coverage assertion (`original-headless.log`, 5 checks/1 failure).

Refresh invalidated ranges after deformation, retaining the complete ordered assembly as one draw. Defensively attach the original drawable mesh if a stale prepared packet reaches spatial splitting. Advance the prepared-world visual key to `track-kit-213-desert-prop-ranges`. Exact array comparison against the captured original deformer confirms unchanged vertices, indices and attributes. This repairs presentation metadata; it does not change authored objects or canonical geometry.

Invisible sand sources could also retain all six slots within a radial 36m lease. Retire a site only after its downwind path, lateral scatter and full billboard envelope leave the shader's visible radius. A six-slot starvation regression now checks this explicitly. Lengthen the existing feathered wisps (maximum 8.5m along wind, 3m across) and independent bursts (2.8–4.6s, bounded to fade before cycle rollover). Keep the terrain pigment hue, with muted airborne scattering calibrated per renderer. Final opacity is 0.23 Mobile/0.24 Compatibility. The same six sites, 48 quads/96 triangles, low lift and depth/roof exclusion remain.

## Actual checks

Godot 4.7.2.stable.official.ed1daf0bf, desktop NVIDIA RTX 3090. Commands and exact outcomes are in [report.json](evidence/desert-visibility-regression-2026-10-24/report.json).

| Retained log | Checks/scripts | Failures |
|---|---:|---:|
{table}

The new fixture enters the real App using isolated temporary records, real CPU preparation and production Game installation. It checks fresh and cached worlds, actual pyramid pixels from both road sides, shared cached mesh resources, prepared sand anchors and released loading barriers. It then advances normal seeded ambience and the ordinary camera along a scripted 50km/h route for 18 seconds. Physics/countdown stay frozen only in the owned capture fixture; this is a presentation diagnostic, not an autonomous driver or FPS benchmark.

Sand at >=1% channel contrast: Mobile {renderers['mobile']['visible_samples']}/18 samples, peak {renderers['mobile']['peak_pixels']} pixels; Compatibility {renderers['gl_compatibility']['visible_samples']}/18, peak {renderers['gl_compatibility']['peak_pixels']}. The additional stricter >=2% check passes in {renderers['mobile']['clear_samples']}/18 and {renderers['gl_compatibility']['clear_samples']}/18 samples respectively. Each qualifying sample needs at least 1,000 pixels; each renderer must have at least nine qualifying samples and a 3,000-pixel peak. The original 1% checks remain. Pixel metrics establish visibility under this fixture, not owner recognition.

The earlier fixed-scenery/original-sand App capture had 10/18 samples and a 3,104-pixel peak on Mobile. Strong-opacity trials were rejected because they violated existing saturation/soft-core invariants. Retained `opacity-*`, `long-wisp-initial-*` and `mobile-saturation-initial.log` document those failures; the final source passes the original thresholds. The initial fixture lacked the offline published-track marker, so the App correctly refused to race; that was a fixture correction, not a runtime bypass. The initial document-key fixture correction is retained separately.

Both renderers preserve all 784 checked opaque roof pixels exactly, with zero bright specks. Pause, background, retry, finish, biome removal and canonical state checks pass. Exact synchronous/cooperative geometry and materials match in all five biomes. Capture logs contain expected hitch diagnostics from explicit GPU readbacks and pixel loops; they are not game frame-rate measurements.

## Review and scope

[Native preview](evidence/desert-visibility-regression-2026-10-24/preview.html) shows the restored pyramids and the exact same driving frame with sand on/off. Its motion links use actual native Game frames with the normal driving camera. No AI-generated screenshots or edited imagery are used.

Changed runtime files: `game/track/native_track_visual.gd` (cache key only), `desert_road_relief.gd` (metadata refresh), `spatial_mesh_chunks.gd` (stale-range retention), `desert_sand_wind.gd` (source leases), `desert_sand_wind.gdshader` (wisps/cadence/scattering). New regression fixture: `game/tests/test_desert_visibility_regression.gd`; existing wind fixture gains an optional evidence-output argument. Status documents and this report record the task. `checkpoint.patch` is relative to task-entry snapshots, preserving the pre-existing dirty tree; reverse application is checked against the working files. Hashes and source snapshots are retained in this evidence directory.

The repaired subdivided Egyptian family uses a complete aggregate draw when its old boundaries are no longer valid. This favours correct complete geometry; reference-device fragment/vertex cost is not measured. Sand has broader transparent coverage at the same instance/triangle budget. Owner recognition on the affected track and physical-device appearance/cost remain to be accepted. The owner has not identified the affected track/platform in this turn. No phone/tablet attachment check, physical-device test, APK/export/install, live account/backend mutation or deployment was performed. Existing owner game/editor processes were preserved. Local game restart is needed to load source changes; installed phone/tablet builds have not been updated.
"""
(ROOT / doc).write_text(description, encoding="utf-8")

status = (
    f"2026-10-24 DVR01-DVR03/R01/G01/Q01: Restore missing Desert pyramids/Egyptian scenery by repairing stale draw ranges after relief subdivision (79098→89883 corners), retaining complete stale sources and advancing the visual cache key. Fix invisible sand source leases and use longer muted terrain-hue wisps within six sites/48quads/96triangles. Actual App cold/cache regression22headless/28Mobile/28Compatibility, wind55/68/68, mesh71, Egyptian79, five-biome exact geometry5, Desert87, biomes108, App141 and parser1044 pass. Ordinary driving sand>=1% contrast {renderers['mobile']['visible_samples']}/18 Mobile/{renderers['gl_compatibility']['visible_samples']}/18 Compatibility; stricter>=2% {renderers['mobile']['clear_samples']}/18/{renderers['gl_compatibility']['clear_samples']}/18. All784 roof pixels exact. Original mismatch and rejected colour trials retained. Commands, native captures, limits and scoped checkpoint: {doc} and docs/evidence/desert-visibility-regression-2026-10-24/report.json. Local restart and owner/affected-track/device appearance/cost acceptance remain; no phone/tablet check/test, APK, live mutation or deployment. Concurrent work and owner processes preserved.\n\n"
)
status_paths = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for relative in status_paths:
    path = ROOT / relative
    before = E / "before" / relative.replace("/", "__")
    if not before.exists():
        before.write_bytes(path.read_bytes())
    if not path.read_text(encoding="utf-8").startswith("## Desert scenery visibility regression" if relative == "AGENTS.md" else "2026-10-24 DVR01"):
        prefix = ("## Desert scenery visibility regression override (2026-10-24)\n" if relative == "AGENTS.md" else "") + status
        path.write_bytes(prefix.encode("utf-8") + path.read_bytes())

relative_e = E.relative_to(ROOT).as_posix()
files = runtime + [wind_test, "game/tests/test_desert_visibility_regression.gd", doc] + status_paths + [relative_e + "/finish_receipt.py", relative_e + "/preview.html"]
manifest = []
patch = []
(E / "after").mkdir(exist_ok=True)
for relative in files:
    path = ROOT / relative
    if relative in runtime or relative == wind_test:
        before = E / "before" / path.name
    elif relative in status_paths:
        before = E / "before" / relative.replace("/", "__")
    else:
        before = None
    after = path.read_text(encoding="utf-8")
    old = before.read_text(encoding="utf-8") if before else ""
    manifest.append(dict(path=relative, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), before_sha256=hashlib.sha256(before.read_bytes()).hexdigest() if before else None))
    (E / "after" / relative.replace("/", "__")).write_bytes(path.read_bytes())
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    patch.extend(difflib.unified_diff(old.splitlines(True), after.splitlines(True), fromfile="a/"+relative if before else "/dev/null", tofile="b/"+relative))
(E / "checkpoint.patch").write_bytes("".join(patch).encode("utf-8"))
git_checks = []
for command in (["git", "diff", "--check", "--"] + files, ["git", "apply", "--reverse", "--check", str(E / "checkpoint.patch")]):
    run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    git_checks.append(dict(command=command, returncode=run.returncode, output=run.stdout+run.stderr))
    assert run.returncode == 0, git_checks[-1]
report = dict(date="2026-10-24", requirements=["DVR01","DVR02","DVR03","R01","G01","Q01"], engine="4.7.2.stable.official.ed1daf0bf", gpu="desktop NVIDIA RTX 3090", tests=tests, native=renderers, changed_files=manifest, git_checks=git_checks, baseline=dict(log="original-headless.log", checks=5, failures=1, old_range=79098, deformed_corners=89883), limitations=["Owner affected track/platform unknown", "Owner visual recognition pending", "No physical-device appearance or cost measurement", "No device attachment check, APK, install or deployment", "Coalesced subdivided Egyptian draw and broader transparent sand require device acceptance", "Owner processes and concurrent changes preserved"])
(E / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"tests":len(tests), "failures":sum(row["failures"] for row in tests), "git_checks":[row["returncode"] for row in git_checks], "report":str(E / "report.json")}))
