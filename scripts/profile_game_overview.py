"""Bounded, offline desktop profiling; preserve commands, sources and raw output."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/game-profile-2026-11-12"
ENGINE = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
PROJECT = ROOT / "build/game-profile-2026-11-12/snapshot/game"


def sources():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in PROJECT.rglob("*") if p.is_file()
            and (".godot" not in p.parts or "imported" in p.parts)
            and ("imported" in p.parts or p.suffix in (".gd", ".godot", ".gdshader", ".json", ".gdextension", ".tscn", ".scn", ".res", ".png", ".dll"))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("script")
    parser.add_argument("--renderer", default="gl_compatibility")
    parser.add_argument("--profile", default="")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--headless", action="store_true")
    args, extra = parser.parse_known_args()
    OUT.mkdir(parents=True, exist_ok=True)
    captures = OUT / args.name
    captures.mkdir(exist_ok=True)
    private = ROOT / "build/game-profile-2026-11-12" / (args.profile or args.name)
    env = dict(os.environ, APPDATA=str(private / "roaming"), LOCALAPPDATA=str(private / "local"),
               BMT_API_URL="", BMT_DEV_AUTH_KEY="", BMT_LOADING_OUTPUT=str(OUT / f"{args.name}-metrics.json"),
               BMT_GRAPHICS_OUTPUT=str(captures))
    Path(env["APPDATA"]).mkdir(parents=True, exist_ok=True)
    Path(env["LOCALAPPDATA"]).mkdir(parents=True, exist_ok=True)
    wrapped = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", str(ENGINE)]
    version = subprocess.check_output(wrapped + ["--version"], text=True).strip()
    assert version == (ROOT / "godot-version.txt").read_text().strip(), version
    command = wrapped + ["--path", str(PROJECT if PROJECT.exists() else ROOT / "game"), "--audio-driver", "Dummy", "--position", "10000,10000",
                         "--rendering-method", args.renderer, "--script", args.script]
    if args.headless:
        command.append("--headless")
    if extra:
        command += extra if extra[0] == "--" else ["--", *extra]
    before = sources()
    (OUT / f"{args.name}-sources.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
    started = time.monotonic()
    log_path = OUT / f"{args.name}.log"
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        (OUT / f"{args.name}-process.json").write_text(json.dumps(dict(pid=process.pid, command=command), indent=2))
        code = None
        while process.poll() is None:
            time.sleep(0.3)
            content = log_path.read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in content or time.monotonic() - started > args.timeout:
                stopped = subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], stdout=log, stderr=subprocess.STDOUT)
                if stopped.returncode:
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        blocked = dict(exit_code=126, cleanup_required=True, pid=process.pid, command=command,
                                       reason="Windows denied termination of this owned profiling tree; stop it before launching another GPU probe.")
                        (OUT / f"{args.name}-receipt.json").write_text(json.dumps(blocked, indent=2))
                        print(json.dumps(blocked), flush=True)
                        return 126
                code = 124 if "SCRIPT ERROR:" not in content else 125
                break
        native_code = process.wait()
    after = sources()
    changed = [p for p in before.keys() | after.keys() if before.get(p) != after.get(p)]
    lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
    errors = list(dict.fromkeys(s for s in lines if s.startswith(("ERROR:", "SCRIPT ERROR:", "WARNING:"))))
    receipt = dict(command=command, engine=version, exit_code=native_code if code is None else code,
                   wall_seconds=round(time.monotonic() - started, 3), source_changes=changed,
                   diagnostics=errors, private_profile=str(private), network="explicitly disabled", audio_driver="Dummy")
    # Keep raw measurements and saves; reclaim only our completed throwaway GPU cache.
    reclaimed = 0
    if not args.profile:
        for cache in private.rglob("shader_cache"):
            resolved = cache.resolve()
            if not resolved.is_relative_to(private.resolve()) or resolved.name != "shader_cache":
                raise ValueError("Unexpected cache cleanup target")
            reclaimed += sum(p.stat().st_size for p in cache.rglob("*") if p.is_file())
            shutil.rmtree(resolved)
    receipt["completed_private_shader_cache_bytes_reclaimed"] = reclaimed
    (OUT / f"{args.name}-receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps(dict(name=args.name, exit_code=receipt["exit_code"], wall_seconds=receipt["wall_seconds"], source_change_count=len(changed), diagnostics=errors)), flush=True)
    print("\n".join(lines[-8:]), flush=True)
    return int(receipt["exit_code"] != 0 or bool(changed) or any(s.startswith("SCRIPT ERROR:") for s in errors))


if __name__ == "__main__":
    sys.exit(main())
