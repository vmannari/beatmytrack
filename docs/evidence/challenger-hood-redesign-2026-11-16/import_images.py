"""Refresh native texture imports in an owned headless editor; verify source MD5s."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/evidence/challenger-hood-redesign-2026-11-16"
PROFILE = ROOT / "build/challenger-hood-redesign-2026-11-16/profile"
env = dict(os.environ, APPDATA=str(PROFILE / "roaming"), LOCALAPPDATA=str(PROFILE / "local"),
           BMT_API_URL="", BMT_DEV_AUTH_KEY="")
project_before = hashlib.sha256((ROOT / "game/project.godot").read_bytes()).hexdigest()
command = [r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64.exe", "--headless", "--editor", "--import",
           "--path", str(ROOT / "game"), "--audio-driver", "Dummy"]
start = time.monotonic()
with (OUT / "image-import.log").open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    (OUT / "image-import-process.json").write_text(json.dumps({"pid": process.pid, "command": command}))
    while process.poll() is None:
        time.sleep(0.3)
        if time.monotonic() - start > 300:
            process.kill()
            raise RuntimeError("Owned image importer exceeded 300 seconds")
    code = process.wait()
assert code == 0, code
assert hashlib.sha256((ROOT / "game/project.godot").read_bytes()).hexdigest() == project_before, "Editor changed project settings"
images = []
for car in ["super_rally"]:
    images += list((ROOT / "game/assets/liveries/previews_v2" / car).glob("*.png"))
    images += [ROOT / "game/assets/menu" / (car + "_illustration_v1.png"),
               ROOT / "game/assets/menu/header_cars_v1" / (car + ".png"),
               ROOT / "game/assets/garage/previews_v1" / (car + ".png"), ROOT / "game/assets/news/vehicles" / (car + ".png")]
images += [ROOT / "game/assets/garage/previews_v1" / (car+".png") for car in ["compact","kart","forklift","electric","hovercraft","super_rally"]]
images = sorted(set(images))
images += list((ROOT / 'game/assets/garage/selection_portraits_v1').glob('*.png'))
rows = []
for image in images:
    metadata = Path(str(image) + ".import").read_text()
    match = re.search(r'path="res://([^\"]+\.ctex)"', metadata)
    assert match, image
    imported = ROOT / "game" / match[1]
    checksum = imported.with_suffix(".md5").read_text()
    digest = hashlib.md5(image.read_bytes()).hexdigest()
    assert imported.is_file() and f'source_md5="{digest}"' in checksum, image
    rows.append({"path": image.relative_to(ROOT).as_posix(), "source_md5": digest})
content = (OUT / "image-import.log").read_text(encoding="utf-8", errors="replace")
diagnostics = [line for line in content.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
(OUT / "image-import-receipt.json").write_text(json.dumps({"exit_code": code, "verified_images": len(rows),
     "seconds": time.monotonic() - start, "project_settings_exact": True, "editor_diagnostics": diagnostics,
     "images": rows}, indent=2))
print(json.dumps({"verified_images": len(rows), "editor_diagnostics": len(diagnostics), "project_settings_exact": True}))

