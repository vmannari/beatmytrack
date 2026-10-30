"""Bounded local Godot verification without the owner's profile or build-ID writes."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["headless", "gl_compatibility", "mobile"], default="headless")
    parser.add_argument("--test", default="test_super_wash")
    parser.add_argument("--label", default="")
    args = parser.parse_args()
    environment = os.environ.copy()
    profile = ROOT / "tmp/super-wash-appdata"
    profile.mkdir(parents=True, exist_ok=True)
    environment["APPDATA"] = str(profile)
    environment["LOCALAPPDATA"] = str(profile)
    environment["BMT_API_URL"] = ""
    executable = environment.get("GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    command = [executable, "--path", str(ROOT / "game"), "--script", "res://tests/" + args.test + ".gd"]
    command += ["--headless"] if args.mode == "headless" else ["--rendering-method", args.mode]
    log = Path(__file__).parent / (args.test + "-" + args.mode + args.label + ".log")
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(command, env=environment, stdout=stream, stderr=subprocess.STDOUT,
                                creationflags=subprocess.CREATE_NO_WINDOW, timeout=240)
    lines = log.read_text(encoding="utf-8").splitlines()
    errors = [line for line in lines if "ERROR:" in line or line.startswith("FAIL:")]
    print(f"{args.test} / {args.mode}: exit {result.returncode}; {len(errors)} error lines; {log.relative_to(ROOT)}")
    for line in lines[-8:]:
        print(line)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
