"""Verify receipts before adding a task-only source checkpoint."""
import difflib
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]

def log_text(name):
    raw = (OUT / name).read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")

specs = [
    ("headless", "test_desert_sand_wind-final.log", "test_desert_sand_wind.gd", "", 52),
    ("Compatibility", "compatibility-final.log", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod gl_compatibility", 62),
    ("desktop Mobile", "mobile-final.log", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod mobile", 62),
    ("Desert", "test_desert-final.log", "test_desert.gd", "", 87),
    ("ambience", "test_desert_ambience-final.log", "test_desert_ambience.gd", "", 111),
    ("biomes", "test_biomes-final.log", "test_biomes.gd", "", 108),
    ("parser", "test_script_parse-final.log", "test_script_parse.gd", "", 934),
]
tests = []
for label, log, script, flags, count in specs:
    expected = f"{count} scripts, 0 failures" if label == "parser" else f"{count} checks, 0 failures"
    if expected not in log_text(log): raise RuntimeError("Missing passing result: " + log)
    command = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/" + script + flags
    tests.append({"name": label, "checks": count, "failures": 0, "log": log, "command": command + " -CommandTimeoutSeconds " + ("240" if flags else "180")})
timelines = {r: json.loads((OUT / r / "timeline.json").read_text()) for r in ["gl_compatibility", "mobile"]}
for value in timelines.values():
    assert 2000 <= value["peak_pixels"] < 9216
    assert value["calm_pixels"] >= 600
    assert value["quiet_pixels"] < value["peak_pixels"] * 0.35

summary = (
    "2026-10-23 SVI01-SVI03/G01/R01/Q01: Owner finds granular Desert wind barely visible. "
    "Raise ordinary/gust strength to0.30/0.95 with square-root opacity, rounded matte flecks, "
    "denser wider local bursts and shorter unequal gaps. Six fixed irregular sites, minimum8m "
    "separation, low hops and lifecycle/depth/canonical fences remain. One bounded4608-instance/9216-triangle "
    "batch increases the previous grain pool fourfold; physical-device cost is unmeasured. "
    "Actual normal-driving-camera peaks303/277 to2190/2130pixels, calm1901/1891, quiet0 and783exact "
    "roof pixels pass. Focused52headless/62Compatibility/62desktopMobile, Desert87, ambience111, "
    "biomes108, parser934 and scoped whitespace pass. Commands, retained initial visibility/style "
    "corrections, native ordinary-camera motion/views and task-only checkpoint: "
    "docs/DESERT_SAND_VISIBILITY_2026_10_23.md. Local client reload, owner appearance and device "
    "performance acceptance remain; no phone attachment check/device test, APK, backend/account "
    "mutation or deployment."
)
base, after = OUT / "task-base", OUT / "task-after"
statuses = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for name in statuses:
    path = ROOT / name
    raw = path.read_bytes()
    if b"2026-10-23 SVI01-SVI03/" in raw:
        if not (base / name).exists(): raise RuntimeError("Missing status snapshot")
        continue
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)
    nl = b"\r\n" if b"\r\n" in raw else b"\n"
    prefix = (b"## More visible granular Desert sand override (2026-10-23)" + nl) if name == "AGENTS.md" else b""
    path.write_bytes(prefix + summary.encode() + nl * 2 + raw)

revisions = ["game/track/desert_sand_wind.gd", "game/track/desert_sand_wind.gdshader", "game/tests/test_desert_sand_wind.gd"]
for name in revisions:
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((OUT / "before" / Path(name).name).read_bytes())
additions = ["docs/DESERT_SAND_VISIBILITY_2026_10_23.md", "docs/evidence/desert-sand-visibility-2026-10-23/encode_preview.py", "docs/evidence/desert-sand-visibility-2026-10-23/finalize_receipt.py"]
files = revisions + statuses + additions
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
report = {
    "date": "2026-10-23", "requirements": ["SVI01", "SVI02", "SVI03", "G01", "R01", "Q01"],
    "engine": "4.7.2.stable.official.ed1daf0bf", "gpu": "NVIDIA GeForce RTX 3090 desktop",
    "tests": tests, "timelines": timelines, "max_patches": 6, "max_grains": 4608, "max_triangles": 9216,
    "previous_peak_pixels": {"gl_compatibility": 303, "mobile": 277},
    "opaque_roof": {"samples_each": 783, "changed_each": 0},
    "preview_encoding": json.loads((OUT / "preview-encoding.json").read_text()),
    "encoder_command": ".tools/review/Scripts/python.exe docs/evidence/desert-sand-visibility-2026-10-23/encode_preview.py",
    "whitespace_command": "git diff --check -- game/track/desert_sand_wind.gd game/track/desert_sand_wind.gdshader game/tests/test_desert_sand_wind.gd",
    "whitespace_exit_code": 0, "retained_attempts": ["compatibility-initial.log", "compatibility-refined.log"],
    "corrections": ["first attempt too bright and rectangular; 1221 peak misses unchanged 2000-pixel floor", "rounded muted denser attempt 1659 still below floor", "wider local grain stream meets unchanged visibility, quiet, coverage and depth checks"],
    "source_sha256": hashes, "patch": "task.patch", "patch_sha256": hashlib.sha256((OUT / "task.patch").read_bytes()).hexdigest(),
    "concurrent_work_preserved": "Only the two sand runtime files and focused fixture change; original sand evidence and all core/backend/native work remain untouched.",
    "acceptance_remaining": ["local client reload", "owner appearance/readability", "physical-device appearance and increased grain-pool cost"],
    "phone_attachment_check": False, "device_test": False, "apk_export_install": False,
    "backend_account_mutation": False, "deployment": False, "performance_claim": "None; GPU vertex and CPU preparation work increase with the pool.",
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("Task-only checkpoint and verified receipt:", len(files), "files")
