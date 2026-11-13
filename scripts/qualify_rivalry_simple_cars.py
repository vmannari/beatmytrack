"""Sequential offline checks in disposable projects with private user profiles."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/rivalry-simple-cars-2026-11-12"
OUT = ROOT / "docs/evidence/rivalry-simple-cars-2026-11-12"
ENGINE = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")


def prepare(full=False):
    project = WORK / ("project/game" if full else "minimal")
    project.mkdir(parents=True, exist_ok=True)
    if full:
        if (WORK / "frozen-source.json").exists():
            # Preserve the other authors' measured source/asset revision. Refresh
            # only this task's own sources; never publish frozen assets to live.
            owned = [*json.loads((WORK / "before.json").read_text()),
                     "game/ui/rivalry_simple_car.gd", "game/tests/test_rivalry_simple_car.gd"]
            for rel in owned:
                target = project / Path(rel).relative_to("game")
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / rel, target)
            return project
        paths = [p for p in (ROOT / "game").rglob("*") if p.is_file()
                 and p.relative_to(ROOT / "game").parts[0] not in ("assets", ".godot", "android", "tmp", "build")]
        for p in paths:
            target = project / p.relative_to(ROOT / "game")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
        cache = project / ".godot"
        cache.mkdir(exist_ok=True)
        for name in ("global_script_class_cache.cfg", "extension_list.cfg", "uid_cache.bin"):
            source = ROOT / "game/.godot" / name
            if source.exists(): shutil.copy2(source, cache / name)
        for link, target in [(project / "assets", ROOT / "game/assets"), (cache / "imported", ROOT / "game/.godot/imported")]:
            if not link.exists():
                subprocess.run(["powershell", "-NoProfile", "-Command",
                                "New-Item -ItemType Junction -Path $env:BMT_TEST_LINK -Target $env:BMT_TEST_TARGET | Out-Null"],
                               env=dict(os.environ, BMT_TEST_LINK=str(link), BMT_TEST_TARGET=str(target)), check=True)
        shutil.copytree(ROOT / "backend/tests/fixtures", project.parent / "backend/tests/fixtures", dirs_exist_ok=True)
    else:
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Rivalry simple car qualification"\n[display]\nwindow/size/viewport_width=1200\nwindow/size/viewport_height=610\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        for rel in ("ui/rivalry_simple_car.gd", "tests/test_rivalry_simple_car.gd"):
            target = project / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / "game" / rel, target)
    return project


def digest(project):
    files = {}
    # Include linked runtime assets/imports as read-only inputs; do not follow
    # links when disposing of these projects after qualification.
    for folder in (project, project / "assets", project / ".godot/imported"):
        if not folder.exists(): continue
        for p in sorted(folder.rglob("*")):
            relative = p.relative_to(project)
            if not p.is_file() or (folder == project and relative.parts[0] in (".godot", "assets")): continue
            files[str(relative).replace("\\", "/")] = hashlib.sha256(p.read_bytes()).hexdigest()
    return hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest(), files


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--renderer", default="gl_compatibility")
    parser.add_argument("--script", default="res://tests/test_rivalry_simple_car.gd")
    parser.add_argument("--profile")
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("arguments", nargs="*")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    project = prepare(args.full)
    if args.baseline:
        shutil.copy2(WORK / "before/game/ui/weekly_rivalry_page.gd", project / "ui/weekly_rivalry_page.gd")
    profile = WORK / "profiles" / (args.profile or args.name)
    for rel in ("roaming", "local"): (profile / rel).mkdir(parents=True, exist_ok=True)
    captures = OUT / args.name
    captures.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile / "roaming"), LOCALAPPDATA=str(profile / "local"),
               BMT_API_URL="", BMT_DEV_AUTH_KEY="", BMT_SIMPLE_CARS_EVIDENCE=str(OUT),
               BMT_RIVALRY_CARS_EVIDENCE_DIR=str(captures), BMT_LOADING_OUTPUT=str(OUT / (args.name+"-timings.json")),
               BMT_GRAPHICS_OUTPUT=str(captures), BMT_RIVALRY_POLISH_EVIDENCE_DIR=str(captures),
               BMT_RIVALRY_READY_CAPTURE_DIR=str(captures), BMT_RIVALRY_READY_PROFILE_ROOT=str(profile))
    wrapper = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", str(ENGINE)]
    version = subprocess.check_output(wrapper+["--version"], text=True).strip()
    assert version == (ROOT / "godot-version.txt").read_text().strip(), version
    command = wrapper+["--path", str(project), "--audio-driver", "Dummy", "--position", "20000,20000",
                       "--rendering-method", args.renderer, "--script", args.script]
    if args.headless: command.append("--headless")
    command += ["--", "--output="+str(OUT / args.name), *args.arguments]
    before, before_files = digest(project)
    started = time.monotonic()
    log_path = OUT / (args.name+".log")
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        while process.poll() is None:
            time.sleep(0.3)
            content = log_path.read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in content or time.monotonic()-started > 240:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], stdout=log, stderr=subprocess.STDOUT)
                break
        code = process.wait()
    after, after_files = digest(project)
    changed = [rel for rel in sorted(before_files.keys() | after_files.keys()) if before_files.get(rel) != after_files.get(rel)]
    content = log_path.read_text(encoding="utf-8", errors="replace")
    diagnostics = [line for line in content.splitlines() if line.startswith(("SCRIPT ERROR:", "ERROR:", "WARNING:", "FAIL:"))]
    invalid = [line for line in diagnostics if "Failed to read the root certificate store" not in line]
    receipt = dict(command=command, engine=version, exit_code=code, seconds=round(time.monotonic()-started,3),
                   before_sha256=before, after_sha256=after, unchanged_project=before==after,
                   changed_files=changed, input_file_count=len(before_files),
                   diagnostics=diagnostics, baseline=args.baseline, full_project=args.full,
                   source_scope=("Private frozen source/assets/imports; only task-owned sources refreshed"
                                 if args.full and (WORK / "frozen-source.json").exists() else
                                 "Private source copy; read-only live asset/import junctions measured before/after"
                                 if args.full else "Minimal isolated project; no game assets or imports"))
    (OUT / (args.name+"-receipt.json")).write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(receipt), flush=True)
    print("\n".join(content.splitlines()[-5:]), flush=True)
    return int(code != 0 or before != after or bool(invalid))


if __name__ == "__main__":
    sys.exit(main())
