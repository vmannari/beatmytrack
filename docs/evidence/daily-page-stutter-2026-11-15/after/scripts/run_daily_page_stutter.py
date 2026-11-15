"""Run offline Daily frame probes/checks with private data and the pinned engine."""
import argparse
import json
import os
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/daily-page-stutter-20261115"
OUT = ROOT / "docs/evidence/daily-page-stutter-2026-11-15"


def instrument(control):
    base = OUT / "before" if control else ROOT
    cache_probe = '''extends RefCounted
const Cache = preload("res://persistence/daily_menu_cache.gd")
static func read(records: LocalRecords, scope: String, kind: String) -> Dictionary:
    var began: int = Time.get_ticks_usec()
    var value: Dictionary = Cache.read(records,scope,kind)
    print("DAILY_SPAN cache_read ",kind," ",(Time.get_ticks_usec()-began)/1000.0)
    return value
static func write(records: LocalRecords, scope: String, kind: String, data: Dictionary) -> void:
    var began: int = Time.get_ticks_usec()
    Cache.write(records,scope,kind,data)
    print("DAILY_SPAN cache_write ",kind," ",(Time.get_ticks_usec()-began)/1000.0)
static func erase(records: LocalRecords, scope: String, kind: String) -> void:
    var began: int = Time.get_ticks_usec()
    Cache.erase(records,scope,kind)
    print("DAILY_SPAN cache_erase ",kind," ",(Time.get_ticks_usec()-began)/1000.0)
'''
    (BUILD / "daily_menu_cache.gd").write_text(cache_probe, encoding="utf-8")
    sources = {
        "game/ui/daily_result_card.gd": ["_ready", "_render", "_render_rows"],
        "game/ui/daily_week.gd": ["refresh"],
        "game/ui/track_of_day_page.gd": ["_ready", "_arrange", "_show_track", "_update_week"],
    }
    for path, methods in sources.items():
        source = (base / path).read_text(encoding="utf-8")
        for method in methods:
            signature = f"func {method}() -> void:"
            source = source.replace(signature, f"func _probe{method}() -> void:")
            source += (
                f"\n{signature}\n\tvar began: int = Time.get_ticks_usec()\n"
                f"\t_probe{method}()\n"
                f'\tprint("DAILY_SPAN {Path(path).stem}.{method} ", '
                "(Time.get_ticks_usec()-began)/1000.0)\n"
            )
        for child in sources:
            if child != path:
                source = source.replace("res://" + child.removeprefix("game/"),
                                        "res://../build/daily-page-stutter-20261115/" + Path(child).name)
        source = source.replace("res://persistence/daily_menu_cache.gd",
                                "res://../build/daily-page-stutter-20261115/daily_menu_cache.gd")
        (BUILD / Path(path).name).write_text(source, encoding="utf-8")
    source = (base / "game/core/features/daily.gd").read_text(encoding="utf-8")
    source = source.replace("res://ui/track_of_day_page.gd",
                            "res://../build/daily-page-stutter-20261115/track_of_day_page.gd")
    source = source.replace("res://persistence/daily_menu_cache.gd",
                            "res://../build/daily-page-stutter-20261115/daily_menu_cache.gd")
    (BUILD / "daily.gd").write_text(source, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("label")
    parser.add_argument("script", nargs="?", default="res://tests/profile_daily_page_stutter.gd")
    parser.add_argument("--renderer", default="gl_compatibility")
    parser.add_argument("--control", action="store_true")
    parser.add_argument("--no-garage", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    instrument(args.control)
    profile = BUILD / args.label
    for folder in ("roaming", "local"):
        (profile / folder).mkdir(parents=True, exist_ok=True)
    output = OUT / args.label
    output.mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile / "roaming"), LOCALAPPDATA=str(profile / "local"),
               BMT_API_URL="", BMT_DEV_AUTH_KEY="", BMT_DAILY_PAGE_OUTPUT=str(output),
               BMT_DAILY_STUTTER_OUTPUT=str(output),
               BMT_DAILY_STUTTER_NO_GARAGE="1" if args.no_garage else "0")
    command = ["C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe", "--path",
               str(ROOT / "game"), "--audio-driver", "Dummy", "--position", "10000,10000",
               "--script", args.script]
    command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer]
    started = time.monotonic()
    log_path = OUT / (args.label + ".log")
    reason = None
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        while process.poll() is None:
            time.sleep(0.2)
            content = log_path.read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in content or time.monotonic() - started > 180:
                reason = "script error" if "SCRIPT ERROR:" in content else "timeout"
                process.kill()
                break
        code = process.wait()
    content = log_path.read_text(encoding="utf-8", errors="replace")
    errors = [line for line in content.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))
              and line != "ERROR: Failed to read the root certificate store."]
    report = {"command": command, "exit_code": code, "seconds": time.monotonic()-started,
              "errors": errors, "stop_reason": reason}
    (OUT / (args.label + "-receipt.json")).write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    print("\n".join(content.splitlines()[-22:]))
    return int(code != 0 or bool(errors) or reason is not None)


if __name__ == "__main__":
    raise SystemExit(main())
