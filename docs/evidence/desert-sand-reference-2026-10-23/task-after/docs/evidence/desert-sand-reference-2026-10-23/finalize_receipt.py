"""Verify actual local receipts and retain a scoped, Git-checked checkpoint."""
import difflib
import hashlib
import json
import re
import subprocess
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PREFIX = "docs/evidence/desert-sand-reference-2026-10-23/"


def read_log(name):
    raw = (OUT / name).read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


def git_check(args, name):
    result = subprocess.run(["git", *args], cwd=ROOT, capture_output=True)
    (OUT / name).write_bytes(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(name + ": " + result.stderr.decode(errors="replace"))
    return {"command": "git " + " ".join(args), "exit_code": result.returncode, "log": name}


specs = [
    ("headless", "headless.log", "test_desert_sand_wind.gd", "", 55),
    ("Compatibility", "compatibility-final.log", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod gl_compatibility", 68),
    ("desktop Mobile", "mobile-final.log", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod mobile", 68),
    ("Desert", "desert.log", "test_desert.gd", "", 87),
    ("ambience", "ambience.log", "test_desert_ambience.gd", "", 111),
    ("biomes", "biomes.log", "test_biomes.gd", "", 108),
    ("parser", "parser.log", "test_script_parse.gd", "", 987),
]
tests = []
for label, log, script, flags, count in specs:
    expected = f"{count} {'scripts' if label == 'parser' else 'checks'}, 0 failures"
    assert expected in read_log(log), log
    assert "FAIL:" not in read_log(log), log
    command = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/" + script + flags
    tests.append({"name": label, "checks": count, "failures": 0, "log": log,
                  "command": command + " -CommandTimeoutSeconds " + ("300" if flags else "240")})
for path in ["regression-exits.json", "native-exits.json"]:
    assert all(row["exit_code"] == 0 for row in json.loads((OUT / path).read_text(encoding="utf-8-sig")))
assert "error=0" in read_log("bake.log")
assert "[ DONE ]" in read_log("import-final.log")
timelines, palettes, roofs = {}, {}, {}
for renderer, log in [("gl_compatibility", "compatibility-final.log"), ("mobile", "mobile-final.log")]:
    timeline = json.loads((OUT / renderer / "timeline.json").read_text())
    palette = json.loads((OUT / renderer / "palette.json").read_text())
    assert 2000 <= timeline["peak_pixels"] < 1280 * 720 * 0.08
    assert timeline["calm_pixels"] >= 600 and timeline["quiet_pixels"] < timeline["peak_pixels"] * 0.35
    assert palette["pixels"] > 1000 and palette["mean_saturation"] < 0.16
    assert palette["bright_specks"] == 0 and palette["contrast_p99"] < 0.20
    roof = re.search(r"SAND_OPAQUE_SAMPLES: (\d+) changed=(\d+)", read_log(log))
    assert roof and int(roof[1]) > 100 and int(roof[2]) == 0
    timelines[renderer], palettes[renderer] = timeline, palette
    roofs[renderer] = {"samples": int(roof[1]), "changed": int(roof[2])}

summary = (
    "2026-10-23 RSP01-RSP03/G01/R01/Q01: Owner rejects yellow Desert flecks and supplies a fine "
    "windblown-sand reference. Muted beige-grey diffuse powder replaces grains, with soft advected "
    "density and independent bursts from actual prepared bank crests. One48-quad/96-triangle batch "
    "and an original mipmapped256-square density texture retain six separated stable sites, depth, "
    "lifecycle, camera and exact driving/canonical guards. Crest preparation inspects at most8192 "
    "vertices and retains512anchors. Focused55headless/68Compatibility/68desktopMobile, Desert87, "
    "ambience111, biomes108, parser987 and import pass. Native colour probes have zero bright "
    "specks, mean saturation0.034/0.093 and contrast p990.071/0.192; all784roof pixels remain exact. "
    "The new reference supersedes grain-only appearance and its coverage ceiling. Actual commands, "
    "retained colour/opacity/capture corrections, native previews, hashes and Git-checked task-only "
    "checkpoint: docs/DESERT_SAND_REFERENCE_2026_10_23.md and "
    "docs/evidence/desert-sand-reference-2026-10-23/report.json. Local client reload, owner appearance "
    "and physical-device cost/appearance acceptance remain. No phone attachment check/device test, "
    "APK, live backend/account mutation or deployment; concurrent work preserved."
)
base, after = OUT / "task-base", OUT / "task-after"
statuses = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for name in statuses:
    path = ROOT / name
    raw = path.read_bytes()
    if b"2026-10-23 RSP01-RSP03/" in raw:
        assert (base / name).exists(), "Missing saved status baseline"
        continue
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)
    nl = b"\r\n" if b"\r\n" in raw else b"\n"
    heading = b"## Reference-coloured Desert wind powder override (2026-10-23)" + nl if name == "AGENTS.md" else b""
    path.write_bytes(heading + summary.encode() + nl * 2 + raw)

revisions = ["game/track/desert_sand_wind.gd", "game/track/desert_sand_wind.gdshader", "game/tests/test_desert_sand_wind.gd", "licenses/ASSETS.md"]
for name in revisions:
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((OUT / "before" / Path(name).name).read_bytes())
additions = ["game/tests/bake_desert_wind_density.gd", "game/tests/bake_desert_wind_density.gd.uid",
             "game/assets/textures/desert_wind_density_v1.png.import", "docs/DESERT_SAND_REFERENCE_2026_10_23.md",
             PREFIX + "encode_preview.py", PREFIX + "finalize_receipt.py"]
asset = "game/assets/textures/desert_wind_density_v1.png"
files = revisions + statuses + additions
patch, hashes = [], {}
for name in files + [asset]:
    path = ROOT / name
    target = after / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(path.read_bytes())
    hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    if name == asset:
        continue
    old = (base / name).read_text(encoding="utf-8").splitlines(True) if (base / name).exists() else []
    new = path.read_text(encoding="utf-8").splitlines(True)
    patch.extend(difflib.unified_diff(old, new, fromfile="a/" + name if old else "/dev/null", tofile="b/" + name))
binary = subprocess.run(["git", "diff", "--no-index", "--binary", "--", "/dev/null", asset], cwd=ROOT, capture_output=True)
assert binary.returncode == 1 and b"GIT binary patch" in binary.stdout
(OUT / "task.patch").write_bytes("".join(patch).encode() + binary.stdout)
checks = [git_check(["diff", "--check", "--", *revisions, *statuses, "docs/DESERT_SAND_REFERENCE_2026_10_23.md"], "whitespace.log"),
          git_check(["apply", "--reverse", "--check", PREFIX + "task.patch"], "checkpoint.log")]
report = {
    "date": "2026-10-23", "requirements": ["RSP01", "RSP02", "RSP03", "G01", "R01", "Q01"],
    "engine": "4.7.2.stable.official.ed1daf0bf", "gpu": "NVIDIA GeForce RTX 3090 desktop",
    "tests": tests, "timelines": timelines, "palettes": palettes, "opaque_roofs": roofs,
    "max_patches": 6, "max_quads": 48, "max_triangles": 96, "max_inspected_crest_vertices": 8192, "max_crest_anchors": 512,
    "density_texture": {"path": asset, "bytes": (ROOT / asset).stat().st_size, "dimensions": [256, 256], "mipmaps": True,
                        "provenance": "Original offline numerical scalar data; no reference pixels/provider output/runtime generation"},
    "bake_command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_desert_wind_density.gd -CommandTimeoutSeconds 180",
    "import_command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180",
    "encoder_command": ".tools/review/Scripts/python.exe " + PREFIX + "encode_preview.py",
    "preview_encoding": json.loads((OUT / "preview-encoding.json").read_text()), "git_checks": checks,
    "retained_attempts": ["compatibility-initial.log", "compatibility-refined.log", "compatibility-mip-042.log", "mobile-opacity-initial.log", "mobile-opacity-030.log", "compatibility-caption.log", "mobile-caption.log"],
    "corrections": ["initial colour probe included warm sun veil; hide/restore it only in disposable palette fixture",
                    "initial powder too subtle; strengthened then reduced opacity to0.28 to meet unchanged Mobile contrast limit",
                    "capture-only pause caption hidden to keep UI out of changed-pixel comparisons"],
    "changed_files": files + [asset], "source_sha256": hashes,
    "patch": "task.patch", "patch_sha256": hashlib.sha256((OUT / "task.patch").read_bytes()).hexdigest(),
    "scope": "Sand runtime, one density asset/recipe, focused fixture and additive documentation only; concurrent work and earlier sand evidence preserved",
    "acceptance_remaining": ["local client reload", "owner colour/movement/natural appearance", "physical-device sustained appearance and fragment cost"],
    "performance_claim": "None; lower triangle count does not establish lower transparent-fragment cost",
    "phone_attachment_check": False, "device_test": False, "apk_export_install": False,
    "backend_account_mutation": False, "deployment": False,
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("Verified native/regression receipts and Git checkpoint:", len(files) + 1, "files")
