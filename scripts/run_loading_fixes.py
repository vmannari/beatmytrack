"""Pinned-engine loading checks with private offline storage and source receipts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/loading-fixes-20261113"
OUT = ROOT / "docs/evidence/loading-fixes-2026-11-13"
ENGINE = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64.exe")


def source_hashes(project):
    return {p.relative_to(project.parent).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in project.rglob("*")
            if p.is_file() and p.suffix in {".gd", ".gdshader", ".gdshaderinc"}
            and not any(x in p.parts for x in (".godot", "tests", "android"))}


def asset_stamps(project):
    # Detect concurrent publication without including hash IO in native timers.
    return {p.relative_to(project.parent).as_posix(): [p.stat().st_size, p.stat().st_mtime_ns]
            for p in (project / "assets").rglob("*")
            if p.is_file() and p.suffix in {".res", ".scn", ".json"}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("label")
    parser.add_argument("script")
    parser.add_argument("--renderer", default="headless",
                        choices=["headless", "gl_compatibility", "mobile"])
    parser.add_argument("--profile", default="checks")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--project", type=Path, default=ROOT / "game")
    args, extra = parser.parse_known_args()
    OUT.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    (BUILD / ".keep").touch()
    profile = BUILD / args.profile
    for folder in ("roaming", "local"):
        (profile / folder).mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile / "roaming"),
               LOCALAPPDATA=str(profile / "local"), BMT_API_URL="", BMT_DEV_AUTH_KEY="",
               BMT_LOADING_FIXES_OUTPUT=str(OUT), BMT_LOADING_FIXES_LABEL=args.label,
               BMT_GRAPHICS_OUTPUT=str(OUT / args.label),
               BMT_GRAPHICS_EVIDENCE=str(OUT / args.label),
               BMT_LOADING_OUTPUT=str(OUT / (args.label + ".json")),
               BMT_LOADING_FIX_OUTPUT=str(OUT / args.label))
    (OUT / args.label).mkdir(exist_ok=True)
    command = [str(ENGINE), "--path", str(args.project.resolve()), "--audio-driver", "Dummy",
               "--position", "10000,10000", "--script", args.script]
    command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer]
    command += extra
    before = source_hashes(args.project)
    assets_before = asset_stamps(args.project)
    started = time.monotonic()
    log_path = OUT / (args.label + ".log")
    reason = None
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                   stderr=subprocess.STDOUT)
        while process.poll() is None:
            time.sleep(0.25)
            content = log_path.read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in content or time.monotonic() - started > args.timeout:
                reason = "script error" if "SCRIPT ERROR:" in content else "timeout"
                process.kill()
                break
        code = process.wait()
    content = log_path.read_text(encoding="utf-8", errors="replace")
    errors = [line for line in content.splitlines()
              if line.startswith(("ERROR:", "SCRIPT ERROR:"))
              and line != "ERROR: Failed to read the root certificate store."]
    after = source_hashes(args.project)
    assets_after = asset_stamps(args.project)
    changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    receipt = {"command": command, "exit_code": code, "stop_reason": reason,
               "seconds": time.monotonic() - started, "errors": errors,
               "changed_sources": changed, "sources_before": before,
               "sources_after": after, "profile": args.profile,
               "changed_assets": sorted(p for p in assets_before.keys() | assets_after.keys()
                                        if assets_before.get(p) != assets_after.get(p)),
               "asset_guard": "size and nanosecond timestamp; not a byte-identity proof"}
    (OUT / (args.label + "-receipt.json")).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    summary = {k: v for k, v in receipt.items() if not k.startswith("sources_")}
    summary["changed_assets_count"] = len(receipt["changed_assets"])
    summary["changed_assets"] = receipt["changed_assets"][:8]
    print(json.dumps(summary, indent=2))
    print("\n".join(content.splitlines()[-12:]))
    return int(code != 0 or bool(errors) or reason is not None)


if __name__ == "__main__":
    raise SystemExit(main())
