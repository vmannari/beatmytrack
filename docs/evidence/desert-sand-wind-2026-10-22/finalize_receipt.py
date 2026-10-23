"""Create an additive task checkpoint while preserving concurrent workspace edits."""
from __future__ import annotations

import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SUMMARY = (
    "2026-10-22 DSW01-DSW03/G01/R01/Q01: Trial Desert wind-lifted sand uses low curved, "
    "branching veils driven by the existing wind audio. One bounded81-instance/2592-triangle "
    "batch reuses the original flow texture and prepared cosmetic ground support; actual "
    "source cells, opaque depth, pause/background/hidden, finish/retry and biome teardown "
    "remain fenced. Canonical driving/track data, camera, vehicle dust and concurrent "
    "graphics work remain. Focused65headless/71Compatibility/71desktopMobile, Desert87, "
    "ambience111, biomes108, parser926, import and scoped whitespace pass. Initial "
    "constant-expression, faint appearance, low-box/fog-colour/pause-overlay fixture "
    "corrections, actual commands, native motion/views and task-only source checkpoint: "
    "docs/DESERT_SAND_WIND_2026_10_22.md. Local client reload and owner density/lift/colour "
    "acceptance remain; no phone attachment check/device test, APK, backend/account "
    "mutation or deployment."
)
existing = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
base = OUT / "task-base"
after = OUT / "task-after"
for name in existing:
    path = ROOT / name
    raw = path.read_bytes()
    if b"2026-10-22 DSW01-DSW03/" in raw:
        if not (base / name).exists():
            raise RuntimeError("Existing status lacks its pre-task snapshot")
        continue
    snapshot = base / name
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_bytes(raw)
    newline = b"\r\n" if b"\r\n" in raw else b"\n"
    if name == "AGENTS.md":
        header, rest = raw.split(newline, 1)
        block = ("\n## Desert wind-lifted sand trial override (2026-10-22)\n" + SUMMARY + "\n").replace("\n", newline.decode()).encode()
        path.write_bytes(header + newline + block + rest)
    else:
        path.write_bytes(SUMMARY.encode() + newline * 2 + raw)

game_path = "game/core/game.gd"
game = (ROOT / game_path).read_text(encoding="utf-8")
blocks = [
    "var desert_sand_wind: DesertSandWind\n",
    "\tif desert_sand_wind != null: desert_sand_wind.present(delta, point, desert_ambience.strength, paused, finish_sim != null)\n",
    "\tif desert_sand_wind != null: desert_sand_wind.reset()\n",
    "\tif desert_sand_wind != null:\n\t\tdesert_sand_wind.get_parent().remove_child(desert_sand_wind)\n\t\tdesert_sand_wind.queue_free()\n\t\tdesert_sand_wind = null\n\tif weather_theme == \"desert\":\n\t\tdesert_sand_wind = DesertSandWind.new()\n\t\t$World.add_child(desert_sand_wind)\n\t\tdesert_sand_wind.configure(native_track, track_ground)\n",
]
task_base_game = game
for block in blocks:
    if task_base_game.count(block) != 1:
        raise RuntimeError("Integration changed concurrently; inspect before checkpointing")
    task_base_game = task_base_game.replace(block, "", 1)
(base / game_path).parent.mkdir(parents=True, exist_ok=True)
(base / game_path).write_text(task_base_game, encoding="utf-8", newline="\n")

additions = [
    "game/track/desert_sand_wind.gd", "game/track/desert_sand_wind.gd.uid",
    "game/track/desert_sand_wind.gdshader", "game/track/desert_sand_wind.gdshader.uid",
    "game/tests/test_desert_sand_wind.gd", "game/tests/test_desert_sand_wind.gd.uid",
    "docs/DESERT_SAND_WIND_2026_10_22.md",
    "docs/evidence/desert-sand-wind-2026-10-22/encode_preview.py",
]
files = [game_path, *existing, *additions]
patch = []
fingerprints = {}
for name in files:
    source = ROOT / name
    snapshot = after / name
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_bytes(source.read_bytes())
    old = (base / name).read_text(encoding="utf-8").splitlines(True) if (base / name).exists() else []
    new = source.read_text(encoding="utf-8").splitlines(True)
    patch.extend(difflib.unified_diff(old, new, fromfile="a/" + name if old else "/dev/null", tofile="b/" + name))
    fingerprints[name] = hashlib.sha256(source.read_bytes()).hexdigest()
(OUT / "task.patch").write_text("".join(patch), encoding="utf-8", newline="\n")

prefix = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/"
checks = [
    ("focused headless", "test_desert_sand_wind.gd", "", "test_desert_sand_wind-final.log", 65),
    ("focused Compatibility", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod gl_compatibility", "compatibility-roof-final.log", 71),
    ("focused desktop Mobile", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod mobile", "mobile-roof-final.log", 71),
    ("existing Desert", "test_desert.gd", "", "test_desert-final.log", 87),
    ("existing Desert ambience", "test_desert_ambience.gd", "", "test_desert_ambience-final.log", 111),
    ("existing biomes", "test_biomes.gd", "", "test_biomes-final.log", 108),
    ("all project scripts", "test_script_parse.gd", "", "test_script_parse-final.log", 926),
]
results = []
for label, script, flags, log, count in checks:
    log_bytes = (OUT / log).read_bytes()
    content = log_bytes.decode("utf-16" if log_bytes.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
    expected = f"{count} scripts, 0 failures" if script == "test_script_parse.gd" else f"{count} checks, 0 failures"
    if expected not in content:
        raise RuntimeError(f"Missing passing result: {log}")
    results.append({"name": label, "command": prefix + script + flags + " -CommandTimeoutSeconds 180", "checks": count, "failures": 0, "log": log})

report = {
    "date": "2026-10-22", "requirements": ["DSW01", "DSW02", "DSW03", "G01", "R01", "Q01"],
    "engine": "4.7.2.stable.official.ed1daf0bf", "desktop_gpu": "NVIDIA GeForce RTX 3090",
    "tests": results, "max_instances": 81, "max_triangles": 2592,
    "depth_roof": {"projected_interior_pixels": 783, "changed_Compatibility": 0, "changed_Mobile": 0},
    "visible_changed_pixels": {"gl_compatibility": 74696, "mobile": 76194},
    "import": {"command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180", "log": "import-final.log", "exit_code": 0},
    "whitespace": {"command": "git diff --check -- game/core/game.gd game/track/desert_sand_wind.gd game/track/desert_sand_wind.gdshader game/tests/test_desert_sand_wind.gd", "exit_code": 0},
    "preview_encoder": ".tools/review/Scripts/python.exe docs/evidence/desert-sand-wind-2026-10-22/encode_preview.py",
    "retained_corrections": ["PowerShell execution policy and sandbox certificate access", "nonconstant vector normalization", "initial overly faint appearance", "low box side visibility counted as roof overpaint", "desktop focus pause overlay", "Mobile fog changed magenta fixture colour; final mask uses projected roof geometry"],
    "source_sha256": fingerprints,
    "patch": "task.patch", "patch_sha256": hashlib.sha256((OUT / "task.patch").read_bytes()).hexdigest(),
    "concurrent_work": "Final game.gd minus only the four exact task blocks is retained as task-base; initial before/game.gd is historical context, not a replacement for newer graphics work.",
    "acceptance_remaining": ["local client restart/reload", "owner density, speed, colour and lift", "physical-device appearance and performance"],
    "phone_attachment_check": False, "physical_device_test": False, "apk_export_install": False,
    "backend_account_mutation": False, "deployment": False,
    "performance_claim": "None. Capture readbacks and fixture stepping emit diagnostic hitch messages, not gameplay measurements.",
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("Task-only patch and receipt written:", len(files), "files")
