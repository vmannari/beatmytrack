"""Create two isolated, offline Android renderer probe projects. No ADB calls.

Copies an immutable source snapshot first, then makes two independent variants.
This script does not export, install, launch, stop or remove any application.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / "build/android-renderer-comparison-20261031"
BASE = TASK / "snapshot"
ORIGINAL_PROBE = ROOT / "docs/evidence/device-performance-race-work-2026-10-27/sources/device_performance_probe.gd"
ORIGINAL_SCENE = ROOT / "docs/evidence/device-performance-race-work-2026-10-27/sources/device_performance_probe.tscn"
FIXTURE = ROOT / "game/tests/fixtures/star_spline_lap.json"
DRIVER_START = ROOT / "tools/android_renderer_comparison/driver_start.gd"
VARIANTS = {"compatibility": ("gl_compatibility", "org.beatmytrack.rendererprobe.gl20261031"),
            "mobile": ("mobile", "org.beatmytrack.rendererprobe.vk20261031")}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(directory: Path) -> dict[str, str]:
    result = {}
    for root, dirs, files in os.walk(directory):
        dirs[:] = [item for item in dirs if item not in {".godot", ".git", "__pycache__"}]
        path = Path(root)
        if path == directory:
            dirs[:] = [item for item in dirs if item != "build"]
        if path.name == "android" and path.parent.name == "game":
            dirs[:] = [item for item in dirs if item != "build"]
        for filename in files:
            if path.name == "android" and path.parent.name == "game" and filename == ".build_version":
                continue
            if filename.startswith("~") and filename.endswith(".dll"):
                continue  # Godot's transient local DLL copy, never source content.
            file = path / filename
            result[file.relative_to(directory).as_posix()] = digest(file)
    return dict(sorted(result.items()))


def excluded(directory: str, names: list[str]) -> set[str]:
    path = Path(directory)
    ignored = {name for name in names if name in {".godot", "__pycache__", ".git"}}
    if path.name == "android" and path.parent.name == "game":
        ignored.add("build")
    return ignored


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise RuntimeError(f"Expected exactly one occurrence: {old[:100]!r}")
    return text.replace(old, new, 1)


def update_driver_start(probe: str) -> str:
    """Keep the stock driver through countdown and the early-throttle window."""
    probe = replace_once(probe, 'var app: Node\n',
                         'const DriverStart = preload("res://diagnostics/driver_start.gd")\nvar app: Node\n')
    probe = replace_once(probe, '\tvar samples: int = 0\n',
                         '\tvar samples: int = 0\n\tvar first_sample_tick: int = -1\n')
    probe = replace_once(probe, '\t\tif game == null: return DriveFrame.new()\n',
                         '\t\tif game == null: return DriveFrame.new()\n'
                         '\t\tif first_sample_tick < 0: first_sample_tick = game.sim.state.tick\n')
    probe = replace_once(probe,
                         '\tgame.driver = input\n'
                         '\twhile game.countdown_ticks>0 and not stopped: await get_tree().process_frame\n'
                         '\tif stopped: return\n',
                         '\twhile is_instance_valid(game) and not DriverStart.ready(game.countdown_ticks, game.sim.state.tick) and not stopped:\n'
                         '\t\tawait get_tree().process_frame\n'
                         '\tif stopped: return\n'
                         '\tif not is_instance_valid(game):\n'
                         '\t\treport.errors.append("race disappeared before driver takeover: "+label)\n'
                         '\t\treturn\n'
                         '\tvar takeover_tick: int = game.sim.state.tick\n'
                         '\tvar takeover_countdown: int = game.countdown_ticks\n'
                         '\tvar launch_early_before_takeover: bool = game.launch_early\n'
                         '\tgame.driver = input\n')
    probe = replace_once(probe, '\tdriving.vehicle = vehicle\n',
                         '\tdriving.vehicle = vehicle\n'
                         '\tdriving.driver_takeover_tick = takeover_tick\n'
                         '\tdriving.driver_takeover_countdown = takeover_countdown\n'
                         '\tdriving.driver_first_sample_tick = input.first_sample_tick\n'
                         '\tdriving.launch_early_before_takeover = launch_early_before_takeover\n'
                         '\tdriving.launch_result = game.sim.state.launch_result\n'
                         '\tdriving.launch_delay_until = game.sim.state.launch_delay_until\n')
    return probe


def main() -> None:
    if TASK.exists():
        raise SystemExit(f"Refusing to overwrite existing task artifacts: {TASK}")
    TASK.mkdir(parents=True)
    BASE.mkdir()
    for name in ("game", "scripts", "native"):
        shutil.copytree(ROOT / name, BASE / name, ignore=excluded)
    shutil.copy2(ROOT / "godot-version.txt", BASE / "godot-version.txt")
    (BASE / ".tools/admob").mkdir(parents=True)
    shutil.copy2(ROOT / ".tools/admob/android_source.zip", BASE / ".tools/admob/android_source.zip")
    # Avoid stale generated Gradle version file: dev.ps1 installs the pinned template.
    (BASE / "game/android/.build_version").unlink(missing_ok=True)
    probe = ORIGINAL_PROBE.read_text(encoding="utf-8")
    probe = update_driver_start(probe)
    # This run uses the same full workload everywhere, without the former
    # package-specific shared-storage mode switch.
    start = probe.index('\tif OS.get_name()=="Android":\n')
    end = probe.index('\treport.mode=mode\n', start)
    probe = probe[:start] + probe[end:]
    probe = replace_once(probe, '"kind":"isolated actual-App Android performance probe"',
                         '"kind":"isolated matched Android renderer comparison"')
    probe = replace_once(probe, 'var stopped: bool = false\n',
                         'var stopped: bool = false\nvar gate_started: bool = false\n')
    probe = replace_once(probe, '\treport.renderer = RenderingServer.get_current_rendering_method()\n',
                         '\treport.renderer = RenderingServer.get_current_rendering_method()\n'
                         '\treport.requested_renderer = str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"))\n')
    # Records real or injected touch receipt only when a touch occurs; no
    # synthetic events are generated and it is not a touch-to-photon measure.
    marker = 'func observe() -> void:\n'
    probe = replace_once(probe, marker,
                         'func _input(event: InputEvent) -> void:\n'
                         '\tif event is InputEventScreenTouch:\n'
                         '\t\tprint("BMT_PERF_TOUCH phase=",phase," pressed=",event.pressed," ticks_us=",Time.get_ticks_usec())\n'
                         '\t\tif event.pressed and not gate_started: gate_started = true\n\n' + marker)
    probe = replace_once(probe, '\trun.call_deferred()\n',
                         '\tvar gate_layer := CanvasLayer.new()\n'
                         '\tgate_layer.layer = 250\n'
                         '\tadd_child(gate_layer)\n'
                         '\tvar gate_label := Label.new()\n'
                         '\tgate_label.text = "Renderer probe ready. Attach collector, then tap to begin."\n'
                         '\tgate_label.position = Vector2(30,100)\n'
                         '\tgate_label.add_theme_font_size_override("font_size",24)\n'
                         '\tgate_layer.add_child(gate_label)\n'
                         '\tvar announced: int = -1000\n'
                         '\twhile not gate_started and not stopped:\n'
                         '\t\tif Time.get_ticks_msec() - announced >= 1000:\n'
                         '\t\t\tannounced = Time.get_ticks_msec()\n'
                         '\t\t\tprint("BMT_PERF_GATE_READY renderer=",RenderingServer.get_current_rendering_method())\n'
                         '\t\tawait get_tree().process_frame\n'
                         '\tgate_layer.queue_free()\n'
                         '\tif stopped: return\n'
                         '\treport.process_startup_excluded = true\n'
                         '\tprint("BMT_PERF_GATE_START ticks_us=",Time.get_ticks_usec())\n'
                         '\trun.call_deferred()\n')
    diagnostics = BASE / "game/diagnostics"
    (diagnostics / "device_performance_probe.gd").write_text(probe, encoding="utf-8", newline="\n")
    shutil.copy2(DRIVER_START, diagnostics / "driver_start.gd")
    shutil.copy2(ORIGINAL_SCENE, diagnostics / "device_performance_probe.tscn")
    perf = BASE / "game/resources/perf"
    perf.mkdir(parents=True, exist_ok=True)
    shutil.copy2(FIXTURE, perf / "star.json")
    game_project = BASE / "game/project.godot"
    text = game_project.read_text(encoding="utf-8")
    text = replace_once(text, 'run/main_scene="res://core/app.tscn"',
                        'run/main_scene="res://diagnostics/device_performance_probe.tscn"')
    text = replace_once(text, 'config/custom_user_dir_name="Circuit01Lab"',
                        'config/custom_user_dir_name="BMTAndroidRendererProbe20261031"')
    game_project.write_text(text, encoding="utf-8", newline="\n")
    preset = BASE / "game/export_presets.cfg"
    text = preset.read_text(encoding="utf-8")
    text = replace_once(text, 'include_filter="', 'include_filter="resources/perf/*.json,resources/storm_tracks/storm_freight.json,')
    text = replace_once(text, 'package/name="CIRCUIT / 01"', 'package/name="BMT Renderer Probe"')
    # The release probe must never make real backend/SDK network calls. The
    # Gradle manifest additionally removes permission introduced by libraries.
    text = replace_once(text, 'permissions/internet=true', 'permissions/internet=false')
    # Two release builds must use the same Android architecture selection.
    text = replace_once(text, 'architectures/x86_64=true', 'architectures/x86_64=false')
    preset.write_text(text, encoding="utf-8", newline="\n")
    dev = BASE / "scripts/dev.ps1"
    text = dev.read_text(encoding="utf-8")
    text = replace_once(text, "'--export-debug', 'Android Debug'", "'--export-release', 'Android Debug'")
    dev.write_text(text, encoding="utf-8", newline="\n")
    snapshot = inventory(BASE)
    for name, (renderer, package) in VARIANTS.items():
        variant = TASK / name
        shutil.copytree(BASE, variant)
        project = variant / "game/project.godot"
        text = project.read_text(encoding="utf-8")
        if renderer == "mobile":
            text = replace_once(text, 'renderer/rendering_method="gl_compatibility"', 'renderer/rendering_method="mobile"')
            text = replace_once(text, 'renderer/rendering_method.mobile="gl_compatibility"', 'renderer/rendering_method.mobile="mobile"')
            text = replace_once(text, 'config/features=PackedStringArray("4.7", "GL Compatibility")',
                                'config/features=PackedStringArray("4.7", "Mobile")')
        project.write_text(text, encoding="utf-8", newline="\n")
        preset = variant / "game/export_presets.cfg"
        text = preset.read_text(encoding="utf-8")
        text = replace_once(text, 'package/unique_name="org.circuit01.handlinglab"', f'package/unique_name="{package}"')
        preset.write_text(text, encoding="utf-8", newline="\n")
        files = inventory(variant)
        differences = [path for path in snapshot if snapshot[path] != files.get(path)]
        expected = ["game/export_presets.cfg"] + (["game/project.godot"] if renderer == "mobile" else [])
        if differences != expected:
            raise RuntimeError(f"Unexpected source differences in {name}: {differences}")
    (TASK / "snapshot-sha256.json").write_text(json.dumps(snapshot, indent=2), encoding="utf-8")
    (TASK / "provenance.json").write_text(json.dumps({
        "engine": (ROOT / "godot-version.txt").read_text().strip(),
        "fixture_sha256": digest(FIXTURE), "probe_sha256": digest(diagnostics / "device_performance_probe.gd"),
        "source_files": len(snapshot), "variants": VARIANTS,
        "snapshot_to_variant_differences": {"compatibility": ["game/export_presets.cfg"],
                                              "mobile": ["game/export_presets.cfg", "game/project.godot"]},
        "device_activity": "none", "offline_intent": "internet permission removed by probe preset and manifest merge; verify final APK",
        "limitations": ["Source was copied from a live workspace, not a frozen commit.",
          "The driver cache may be shared across package IDs.", "This tool does not establish presented-frame boundaries or physical input latency."]
    }, indent=2), encoding="utf-8")
    print(json.dumps({"task": str(TASK), "source_files": len(snapshot), "variants": VARIANTS}, indent=2))


if __name__ == "__main__":
    main()
