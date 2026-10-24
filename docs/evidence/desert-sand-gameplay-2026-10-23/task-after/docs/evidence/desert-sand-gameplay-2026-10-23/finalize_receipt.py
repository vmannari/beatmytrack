"""Retain actual gameplay/material receipts and a task-only checked patch."""
import difflib
import hashlib
import json
import re
import subprocess
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PREFIX = "docs/evidence/desert-sand-gameplay-2026-10-23/"
DOC = "docs/DESERT_SAND_GAMEPLAY_2026_10_23.md"


def log_text(name):
    raw = (OUT / name).read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


specs = [
    ("gameplay-headless", "test_desert_sand_gameplay.gd", ""),
    ("gameplay-mobile", "test_desert_sand_gameplay.gd", "mobile"),
    ("gameplay-compatibility", "test_desert_sand_gameplay.gd", "gl_compatibility"),
    ("focused-headless", "test_desert_sand_wind.gd", ""),
    ("focused-mobile", "test_desert_sand_wind.gd", "mobile"),
    ("focused-compatibility", "test_desert_sand_wind.gd", "gl_compatibility"),
    ("desert", "test_desert.gd", ""), ("ambience", "test_desert_ambience.gd", ""),
    ("biomes", "test_biomes.gd", ""), ("parser", "test_script_parse.gd", ""),
]
tests = []
for name, script, method in specs:
    log = log_text(name + ".log")
    result = re.search(r"(\d+) (checks|scripts), 0 failures", log)
    assert result and "FAIL:" not in log and "SCRIPT ERROR:" not in log and "Command failed" not in log, name
    flags = " -Graphical -RenderingMethod " + method if method else ""
    tests.append({"name": name, "checks": int(result[1]), "failures": 0, "log": name + ".log",
                  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/" + script + flags + " -CommandTimeoutSeconds 300"})
exits = {row["name"]: row for row in json.loads((OUT / "regression-exits.json").read_text(encoding="utf-8-sig"))}
exits.update({row["name"]: row for row in json.loads((OUT / "compatibility-exits.json").read_text(encoding="utf-8-sig"))})
assert all(row["exit_code"] == 0 for row in exits.values())
original = json.loads((OUT / "before/driving-original.json").read_text())
assert original["visible_samples"] == 0 and original["peak_pixels"] == 170
assert "6 checks, 2 failures" in log_text("gameplay-original.log")
measurements = {}
for renderer, log in [("mobile", "focused-mobile.log"), ("gl_compatibility", "focused-compatibility.log")]:
    driving = json.loads((OUT / renderer / "driving.json").read_text())
    timeline = json.loads((OUT / "focused" / renderer / "timeline.json").read_text())
    palette = json.loads((OUT / "focused" / renderer / "palette.json").read_text())
    assert driving["visible_samples"] >= 9 and driving["peak_pixels"] >= 3000
    assert len(driving["samples"]) == 18
    assert 2000 <= timeline["peak_pixels"] < 1280 * 720 * 0.08
    assert timeline["calm_pixels"] >= 600 and timeline["quiet_pixels"] < timeline["peak_pixels"] * 0.35
    assert palette["pixels"] > 1000 and palette["mean_saturation"] < 0.16 and palette["terrain_hue_error"] < 0.04
    assert palette["bright_specks"] == 0 and palette["contrast_p99"] < 0.20
    roof = re.search(r"SAND_OPAQUE_SAMPLES: (\d+) changed=(\d+)", log_text(log))
    assert roof and int(roof[1]) > 100 and int(roof[2]) == 0
    measurements[renderer] = {"driving": driving, "focused_timeline": timeline, "palette": palette,
                              "roof": {"samples": int(roof[1]), "changed": int(roof[2])}}
counts = {row["name"]: row["checks"] for row in tests}
check_text = ("<!-- CHECKS -->\n\nFinal normal-wind route presentation produces **9/18 readable samples in each renderer**, with peaks **4,548 Mobile / 6,389 Compatibility** perceptibly changed pixels, against the original Mobile peak of170. Gameplay checks pass **{gameplay-headless} headless / {gameplay-mobile} Mobile / {gameplay-compatibility} Compatibility**. Existing focused checks pass **{focused-headless}/{focused-mobile}/{focused-compatibility}**; Desert **{desert}**, ambience **{ambience}**, biomes **{biomes}** and parser **{parser} scripts** pass. All784 roof pixels stay exact in each renderer. The unchanged colour/contrast limits pass, with zero bright saturated specks. These are visibility and regression observations, not visual-quality or performance certification.").format(**counts)
path = ROOT / DOC
path.write_text(re.sub(r"<!-- CHECKS -->.*?(?=\n\n- \[Mobile)", check_text, path.read_text(encoding="utf-8"), flags=re.S), encoding="utf-8", newline="\n")
summary = ("2026-10-23 SGP01-SGP03/G01/R01/Q01: Owner cannot notice Desert wind in-game. Reproduce through actual Game presentation, normal seeded ambience and moving driving camera: original0/18 readable samples and170perceptible peak pixels. Raise ordinary visual floor0.30to0.65, strengthen thin wisps with0.20sqrt(shape) and retain terrain hue through renderer-calibrated airborne value. Six stable separated sites,48quads/96triangles, audio, camera, depth and canonical/lifecycle guards remain. Final9/18samples per renderer, peaks4548Mobile/6389Compatibility; gameplay{gameplay-headless}/{gameplay-mobile}/{gameplay-compatibility}, focused{focused-headless}/{focused-mobile}/{focused-compatibility}, Desert{desert}, ambience{ambience}, biomes{biomes} and parser{parser} pass; all784roof pixels remain exact. Actual ordinary-driving previews, retained fixture/material corrections, commands, hashes and scoped Git-checked checkpoint: docs/DESERT_SAND_GAMEPLAY_2026_10_23.md and docs/evidence/desert-sand-gameplay-2026-10-23/report.json. Local restart, owner recognition and physical-device fragment cost/appearance remain. No phone/tablet attachment check, physical-device test, APK, live account/backend mutation or deployment. Concurrent work and owner game/editor processes preserved.").format(**counts)
base, after = OUT / "task-base", OUT / "task-after"
statuses = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for name in statuses:
    path = ROOT / name
    raw = path.read_bytes()
    if b"2026-10-23 SGP01-SGP03/" in raw:
        assert (base / name).exists()
        continue
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)
    nl = b"\r\n" if b"\r\n" in raw else b"\n"
    heading = b"## Desert sand visibility during ordinary driving override (2026-10-23)" + nl if name == "AGENTS.md" else b""
    path.write_bytes(heading + summary.encode() + nl * 2 + raw)
revisions = ["game/track/desert_sand_wind.gd", "game/track/desert_sand_wind.gdshader", "game/tests/test_desert_sand_wind.gd"]
for name in revisions:
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((OUT / "before" / Path(name).name).read_bytes())
files = revisions + statuses + ["game/tests/test_desert_sand_gameplay.gd", "game/tests/test_desert_sand_gameplay.gd.uid", DOC, PREFIX + "encode_preview.py", PREFIX + "finalize_receipt.py"]
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
report = {"date": "2026-10-23", "requirements": ["SGP01", "SGP02", "SGP03", "G01", "R01", "Q01"],
          "engine": "4.7.2.stable.official.ed1daf0bf", "gpu": "NVIDIA GeForce RTX 3090 desktop",
          "tests": tests, "original_driving": original, "measurements": measurements, "git_checks": git_checks,
          "visibility_definition": "Perceptible pixel: absolute change>=0.01 in at least one RGB channel in paired native images; readable sample>=1000pixels",
          "capture_scope": "18s scripted route at14m/s through actual Game presentation and seeded normal ambience; physics disabled, no forced gust",
          "retained_attempts": ["coverage-original.log", "creator-wait-initial.log", "creator-invalid-length.log", "creator-original.log", "capture-settle-initial.log", "gameplay-original.log", "gameplay-wisps-initial.log", "colour-compatibility-initial.log"],
          "corrections": ["legal circuit length and immediate biome validation", "elapsed-time preparation wait", "three settled draws per paired visibility state", "thin-wisp response and normal strength alone still insufficient", "sunlit value with separate Compatibility calibration retains original hue limit"],
          "changed_files": files, "source_sha256": hashes, "patch": "task.patch", "patch_sha256": hashlib.sha256((OUT / "task.patch").read_bytes()).hexdigest(),
          "preview_encoding": json.loads((OUT / "preview-encoding.json").read_text()),
          "encoder_command": ".tools/review/Scripts/python.exe " + PREFIX + "encode_preview.py",
          "performance_claim": "None; transparent fragment work can increase despite unchanged48quad geometry",
          "acceptance_remaining": ["local game restart", "owner recognition/appearance on usual track", "sustained physical-device appearance and fragment cost"],
          "testing_platform_answer_received": False, "phone_tablet_attachment_check": False, "physical_device_test": False,
          "apk_export_install": False, "live_mutation": False, "deployment": False, "concurrent_work_preserved": True}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("Verified receipts and task-only Git checkpoint:", len(files), "files")
