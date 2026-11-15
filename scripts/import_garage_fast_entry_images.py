"""Import only the six published Garage photographs in a private editor project."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/garage-fast-entry-2026-11-14/image-import"
PROJECT = WORK / "game"


def main():
    PROJECT.mkdir(parents=True, exist_ok=True)
    (PROJECT / "project.godot").write_text('[application]\nconfig/name="Garage image import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    catalog = (ROOT / "game/vehicle/vehicle_catalog.gd").read_text()
    selected = re.search(r'const IDS: Array\[String\] = \[([^\]]+)\]', catalog)
    assert selected
    images = [ROOT / "game/assets/garage/previews_v1" / (car + ".png")
              for car in re.findall(r'"([^"]+)"', selected.group(1))]
    assert len(images) == 6
    before = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in images}
    for image in images:
        target = PROJECT / image.relative_to(ROOT / "game")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(image, target)
        shutil.copy2(Path(str(image) + ".import"), Path(str(target) + ".import"))
    command = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--",
               r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
               "--headless", "--editor", "--import", "--path", str(PROJECT), "--audio-driver", "Dummy"]
    with (WORK / "run.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, env=dict(os.environ, APPDATA=str(WORK / "profile"),
                                LOCALAPPDATA=str(WORK / "profile/local")), stdout=log,
                                stderr=subprocess.STDOUT, timeout=120)
    assert result.returncode == 0
    diagnostics = [line for line in (WORK / "run.log").read_text().splitlines()
                   if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
    assert not diagnostics, diagnostics
    assert all(hashlib.sha256(p.read_bytes()).hexdigest() == value for p, value in before.items())
    rows = []
    for image in images:
        relative = image.relative_to(ROOT / "game")
        metadata = Path(str(PROJECT / relative) + ".import")
        match = re.search(r'path="res://([^\"]+\.ctex)"', metadata.read_text())
        assert match, image
        texture = Path(match[1])
        checksum = (PROJECT / texture.with_suffix(".md5")).read_text()
        digest = hashlib.md5(image.read_bytes()).hexdigest()
        assert f'source_md5="{digest}"' in checksum
        for source, target in [(metadata, Path(str(image) + ".import")),
                               (PROJECT / texture, ROOT / "game" / texture),
                               (PROJECT / texture.with_suffix(".md5"), ROOT / "game" / texture.with_suffix(".md5"))]:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        rows.append({"path": relative.as_posix(), "source_md5": digest})
    (WORK / "receipt.json").write_text(json.dumps(dict(command=command, exit_code=result.returncode,
        diagnostics=diagnostics, images=rows), indent=2))
    print("Verified and published", len(rows), "native image imports")


if __name__ == "__main__":
    main()
