"""Run daily-page checks with the pinned engine and private, offline user data."""
import argparse
import json
import os
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/daily-page-loading-20261114"
OUT = ROOT / "docs/evidence/daily-page-loading-2026-11-14"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("label")
    parser.add_argument("script")
    parser.add_argument("--renderer", default="headless")
    parser.add_argument("--control", action="store_true")
    parser.add_argument("--profile")
    parser.add_argument("--phase", default="checks", choices=["checks", "seed", "restore"])
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    if args.control:
        source = (OUT / "before/game/ui/track_of_day_page.gd").read_text(encoding="utf-8")
        source = source.replace("res://ui/daily_result_card.gd",
                                "res://../docs/evidence/daily-page-loading-2026-11-14/before/game/ui/daily_result_card.gd")
        (BUILD / "control_page.gd").write_text(source, encoding="utf-8")
    profile = BUILD / (args.profile or args.label)
    for folder in ("roaming", "local"):
        (profile / folder).mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile / "roaming"), LOCALAPPDATA=str(profile / "local"),
               BMT_API_URL="", BMT_DEV_AUTH_KEY="", BMT_DAILY_PAGE_OUTPUT=str(OUT / args.label),
               BMT_DAILY_PAGE_CONTROL="1" if args.control else "0",
               BMT_DAILY_PAGE_PHASE=args.phase,
               BMT_DAILY_MEDAL_OUTPUT=str(OUT / args.label))
    (OUT / args.label).mkdir(exist_ok=True)
    command = ["C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe",
               "--path", str(ROOT / "game"), "--audio-driver", "Dummy", "--position", "10000,10000",
               "--script", args.script]
    command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer]
    started = time.monotonic()
    log_path = OUT / (args.label + ".log")
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        reason = None
        while process.poll() is None:
            time.sleep(0.2)
            content = log_path.read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in content or time.monotonic() - started > 240:
                reason = "script error" if "SCRIPT ERROR:" in content else "timeout"
                process.kill()
                break
        code = process.wait()
    content = log_path.read_text(encoding="utf-8", errors="replace")
    errors = [line for line in content.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))
              and line != "ERROR: Failed to read the root certificate store."]
    report = {"command": command, "exit_code": code, "seconds": time.monotonic()-started,
              "errors": errors, "stop_reason": reason}
    (OUT / (args.label+"-receipt.json")).write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    print("\n".join(content.splitlines()[-24:]))
    return int(code != 0 or bool(errors) or reason is not None)


if __name__ == "__main__":
    raise SystemExit(main())
