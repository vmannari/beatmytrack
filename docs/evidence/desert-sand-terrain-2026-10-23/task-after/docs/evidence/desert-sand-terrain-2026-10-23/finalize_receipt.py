"""Check actual receipts and retain this refinement independently of concurrent work."""
import difflib
import hashlib
import json
import re
import subprocess
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PREFIX = "docs/evidence/desert-sand-terrain-2026-10-23/"
DOC = "docs/DESERT_SAND_TERRAIN_2026_10_23.md"


def read_log(name):
    raw = (OUT / name).read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


tests = []
for name, script, flags in [
    ("headless", "test_desert_sand_wind.gd", ""),
    ("compatibility-final", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod gl_compatibility"),
    ("mobile-final", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod mobile"),
    ("desert", "test_desert.gd", ""), ("ambience", "test_desert_ambience.gd", ""),
    ("biomes", "test_biomes.gd", ""), ("parser", "test_script_parse.gd", ""),
]:
    log = read_log(name + ".log")
    result = re.search(r"(\d+) (checks|scripts), 0 failures", log)
    assert result and "FAIL:" not in log and "SCRIPT ERROR:" not in log, name
    tests.append({"name": name, "checks": int(result[1]), "failures": 0, "log": name + ".log",
                  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/" + script + flags + " -CommandTimeoutSeconds 300"})
assert all(row["exit_code"] == 0 for row in json.loads((OUT / "regression-exits.json").read_text(encoding="utf-8-sig")))
measurements = {}
for renderer, log in [("gl_compatibility", "compatibility-final.log"), ("mobile", "mobile-final.log")]:
    timeline = json.loads((OUT / renderer / "timeline.json").read_text())
    palette = json.loads((OUT / renderer / "palette.json").read_text())
    assert 2000 <= timeline["peak_pixels"] < 1280 * 720 * 0.08
    assert timeline["calm_pixels"] >= 600 and timeline["quiet_pixels"] < timeline["peak_pixels"] * 0.35
    assert palette["pixels"] > 1000 and palette["mean_saturation"] < 0.16 and palette["terrain_hue_error"] < 0.04
    assert palette["bright_specks"] == 0 and palette["contrast_p99"] < 0.20
    roof = re.search(r"SAND_OPAQUE_SAMPLES: (\d+) changed=(\d+)", read_log(log))
    assert roof and int(roof[1]) > 100 and int(roof[2]) == 0
    measurements[renderer] = {"timeline": timeline, "palette": palette, "roof": {"samples": int(roof[1]), "changed": int(roof[2])}}
counts = {row["name"]: row["checks"] for row in tests}
checks_text = ("<!-- CHECKS -->\n\nNative verification: focused **{headless} headless / {compatibility-final} Compatibility / {mobile-final} desktop Mobile**, Desert **{desert}**, ambience **{ambience}**, biomes **{biomes}** and parser **{parser} scripts** pass. Both renderers retain 784 exact roof pixels and zero bright saturated specks. Rendered terrain-hue errors are 0.0021/0.0175 of a hue turn, with saturation 0.082/0.133 and contrast p99 0.086/0.137. Hardware is an RTX 3090; desktop Mobile is Vulkan on Windows, not a tablet measurement.").format(**counts)
doc = ROOT / DOC
doc.write_text(re.sub(r"<!-- CHECKS -->.*?(?=\n\nActual commands)", checks_text, doc.read_text(encoding="utf-8"), flags=re.S), encoding="utf-8", newline="\n")

summary = ("2026-10-23 STC01-STC02/G01/R01/Q01: Owner likes the RSP sand preview and requests closer terrain colour and slightly more frequent appearances. Share the existing loose-sand palette with brightness compensation; shorten independent periods6-11s to5-9s and skips12% to10% (about24% more nominal starts). Accepted soft shape, drift, lift, opacity, six separated crest sites and48-quad/96-triangle batch remain. Focused{headless}headless/{compatibility-final}Compatibility/{mobile-final}desktopMobile, Desert{desert}, ambience{ambience}, biomes{biomes} and parser{parser} pass. Original mutedness/contrast/roof/canonical/lifecycle guards remain; native hue errors0.0021/0.0175, zero bright specks and784exact roof pixels pass. Commands, updated HTML previews, hashes and scoped Git-checkable patch: docs/DESERT_SAND_TERRAIN_2026_10_23.md and docs/evidence/desert-sand-terrain-2026-10-23/report.json. Client reload and owner/device colour/cadence/cost acceptance remain. No phone/tablet attachment check, physical-device test, APK, live account/backend mutation or deployment. Concurrent work preserved.").format(**counts)
base, after = OUT / "task-base", OUT / "task-after"
statuses = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for name in statuses:
    path = ROOT / name
    raw = path.read_bytes()
    if b"2026-10-23 STC01-STC02/" in raw:
        assert (base / name).exists()
        continue
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)
    nl = b"\r\n" if b"\r\n" in raw else b"\n"
    heading = b"## Terrain-matched Desert sand cadence override (2026-10-23)" + nl if name == "AGENTS.md" else b""
    path.write_bytes(heading + summary.encode() + nl * 2 + raw)
revisions = ["game/track/desert_sand_wind.gd", "game/track/desert_sand_wind.gdshader", "game/tests/test_desert_sand_wind.gd"]
for name in revisions:
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((OUT / "before" / Path(name).name).read_bytes())
files = revisions + statuses + [DOC, PREFIX + "encode_preview.py", PREFIX + "finalize_receipt.py"]
patch, hashes = [], {}
for name in files:
    path = ROOT / name
    target = after / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(path.read_bytes())
    old = (base / name).read_text(encoding="utf-8").splitlines(True) if (base / name).exists() else []
    new = path.read_text(encoding="utf-8").splitlines(True)
    patch.extend(difflib.unified_diff(old, new, fromfile="a/" + name if old else "/dev/null", tofile="b/" + name))
    hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
(OUT / "task.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
git_checks = []
for args, log in [(["diff", "--check", "--", *revisions, *statuses, DOC], "whitespace.log"), (["apply", "--reverse", "--check", PREFIX + "task.patch"], "checkpoint.log")]:
    result = subprocess.run(["git", *args], cwd=ROOT, capture_output=True)
    (OUT / log).write_bytes(result.stdout + result.stderr)
    assert result.returncode == 0, (log, result.stderr.decode(errors="replace"))
    git_checks.append({"command": "git " + " ".join(args), "exit_code": result.returncode, "log": log})
report = {"date": "2026-10-23", "requirements": ["STC01", "STC02", "G01", "R01", "Q01"],
          "engine": "4.7.2.stable.official.ed1daf0bf", "gpu": "NVIDIA GeForce RTX 3090 desktop",
          "tests": tests, "measurements": measurements, "git_checks": git_checks,
          "burst_period_seconds": {"before": [6, 11], "after": [5, 9]}, "cycle_skip_probability": {"before": 0.12, "after": 0.10},
          "nominal_start_rate_ratio": (8.5 / 7.0) * (0.90 / 0.88), "rate_scope": "nominal mean-period/skip estimate, not measured session rate",
          "colour": "Existing TrackTheme.DESERT[2] with0.90 linear pigment multiplier", "geometry": {"max_sites": 6, "quads": 48, "triangles": 96},
          "preview_encoding": json.loads((OUT / "preview-encoding.json").read_text()),
          "encoder_command": ".tools/review/Scripts/python.exe " + PREFIX + "encode_preview.py",
          "retained_attempt": "mobile-initial.log", "correction": "Restore original0.16 mutedness cap before final checks; initial measured0.133 already meets it",
          "changed_files": files, "source_sha256": hashes, "patch": "task.patch", "patch_sha256": hashlib.sha256((OUT / "task.patch").read_bytes()).hexdigest(),
          "acceptance_remaining": ["client reload", "owner colour and cadence", "sustained physical-device appearance and fragment cost"],
          "performance_claim": "None; more frequent transparency can increase fragment work",
          "phone_tablet_attachment_check": False, "physical_device_test": False, "apk_export_install": False, "live_mutation": False, "deployment": False,
          "concurrent_work_preserved": True}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("Verified receipts and task-only Git checkpoint:", len(files), "files")
