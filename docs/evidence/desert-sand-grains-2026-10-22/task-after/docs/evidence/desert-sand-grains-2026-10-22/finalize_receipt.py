"""Record passing checks and checkpoint only this revision's source changes."""
import difflib
import hashlib
import json
import re
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]

def read_log(name):
    data = (OUT / name).read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")

specs = [
    ("focused headless", "test_desert_sand_wind-final.log", "test_desert_sand_wind.gd", "", 52),
    ("focused Compatibility", "compatibility-final.log", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod gl_compatibility", 60),
    ("focused desktop Mobile", "mobile-retry-final.log", "test_desert_sand_wind.gd", " -Graphical -RenderingMethod mobile", 60),
    ("existing Desert", "test_desert-final.log", "test_desert.gd", "", 87),
    ("existing ambience", "test_desert_ambience-final.log", "test_desert_ambience.gd", "", 111),
    ("existing biomes", "test_biomes-final.log", "test_biomes.gd", "", 108),
    ("all project scripts", "test_script_parse-final.log", "test_script_parse.gd", "", 932),
]
tests = []
for label, log, script, flags, count in specs:
    text = read_log(log)
    expected = f"{count} scripts, 0 failures" if script == "test_script_parse.gd" else f"{count} checks, 0 failures"
    if expected not in text:
        raise RuntimeError(f"Missing passing result in {log}")
    command = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/" + script + flags
    command += " -CommandTimeoutSeconds " + ("240" if flags else "180")
    tests.append({"name": label, "log": log, "checks": count, "failures": 0, "command": command})

summary = (
    "2026-10-22 SGR01-SGR03/G01/R01/Q01: Owner rejects the first Desert wind as gas-like and systematic. "
    "Individual earthy flecks make short3-28cm hops from at most six irregular separated patches, with "
    "independent brief bursts, skipped cycles and quiet intervals. One1152-instance/2304-triangle batch "
    "removes the broad veils/flow texture; visible sites retain exact world positions across collection "
    "cells. Existing prepared ground support, depth, lifecycle, camera, vehicle dust, audio and canonical "
    "behavior remain. Focused52headless/60Compatibility/60desktopMobile, Desert87, ambience111, biomes108, "
    "parser932 and scoped whitespace pass; native peaks303/277pixels include fully quiet samples and "
    "783exact roof pixels. Actual commands, native motion/views, first subpixel/capture corrections, "
    "resolved concurrent DLL startup failure and task-only checkpoint: docs/DESERT_SAND_GRAINS_2026_10_22.md. "
    "Local client reload and owner appearance acceptance remain; no phone attachment check/device test, "
    "APK, backend/account mutation or deployment. Supersedes the previous DSW broad-veils trial."
)
base = OUT / "task-base"
after = OUT / "task-after"
statuses = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for name in statuses:
    path = ROOT / name
    raw = path.read_bytes()
    if b"2026-10-22 SGR01-SGR03/" in raw:
        if not (base / name).exists(): raise RuntimeError("Missing original status snapshot")
        continue
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)
    nl = b"\r\n" if b"\r\n" in raw else b"\n"
    if name == "AGENTS.md":
        header, rest = raw.split(nl, 1)
        block = nl + b"## Sparse granular Desert wind override (2026-10-22)" + nl + summary.encode() + nl
        path.write_bytes(header + nl + block + rest)
    else:
        path.write_bytes(summary.encode() + nl * 2 + raw)

revisions = {
    "game/track/desert_sand_wind.gd": "desert_sand_wind.gd",
    "game/track/desert_sand_wind.gdshader": "desert_sand_wind.gdshader",
    "game/tests/test_desert_sand_wind.gd": "test_desert_sand_wind.gd",
}
for name, old in revisions.items():
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((OUT / "before" / old).read_bytes())
additions = [
    "docs/DESERT_SAND_GRAINS_2026_10_22.md",
    "docs/evidence/desert-sand-grains-2026-10-22/encode_preview.py",
    "docs/evidence/desert-sand-grains-2026-10-22/finalize_receipt.py",
]
files = [*revisions, *statuses, *additions]
patch = []
hashes = {}
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
timelines = {r: json.loads((OUT / r / "timeline.json").read_text()) for r in ["gl_compatibility", "mobile"]}
report = {
    "date": "2026-10-22", "requirements": ["SGR01", "SGR02", "SGR03", "G01", "R01", "Q01"],
    "engine": "4.7.2.stable.official.ed1daf0bf", "desktop_gpu": "NVIDIA GeForce RTX 3090",
    "tests": tests, "max_patches": 6, "max_instances": 1152, "max_triangles": 2304,
    "minimum_site_separation_m": 8, "max_hop_above_source_m": 0.28,
    "timelines": timelines, "opaque_roof": {"interior_pixels_each_renderer": 783, "changed_pixels_each_renderer": 0},
    "preview_encoding": json.loads((OUT / "preview-encoding.json").read_text()),
    "whitespace_command": "git diff --check -- game/track/desert_sand_wind.gd game/track/desert_sand_wind.gdshader game/tests/test_desert_sand_wind.gd",
    "whitespace_exit_code": 0,
    "retained_attempts": ["headless-initial.log", "compatibility-initial.log", "compatibility-readable.log", "mobile-final.log", "mobile-refined-final.log"],
    "corrections": ["unsupported combined delete/add patch rejected atomically", "subpixel first grains enlarged for overhead readability", "visible sites retained across collection cells", "detail source selected from actual emitted-pixel centroid", "concurrent audio DLL became available without modifying audio work"],
    "source_sha256": hashes, "patch": "task.patch", "patch_sha256": hashlib.sha256((OUT / "task.patch").read_bytes()).hexdigest(),
    "concurrent_work_preserved": "No core/game.gd or native/audio changes. Source diff starts at the saved first sand trial; status edits are additive.",
    "acceptance_remaining": ["local client reload", "owner grain readability and natural patch/burst appearance", "physical-device appearance and performance"],
    "phone_attachment_check": False, "physical_device_test": False, "apk_export_install": False,
    "backend_account_mutation": False, "deployment": False, "performance_claim": "None; capture readbacks are fixture-only.",
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("Checkpoint and receipt written:", len(files), "task files")
