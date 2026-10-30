"""Import the new cutout alone using the retained mitt/hose texture settings."""
from pathlib import Path
import hashlib
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
PROJECT = ROOT / "build/super-wash-automatic-import"
relative = Path("assets/menu/garage/super-v2.png")
target = PROJECT / relative
target.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / "game" / relative, target)
(PROJECT / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Super Wash image import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
settings = (ROOT / "game/assets/menu/garage/mitt-v1.png.import").read_text(encoding="utf-8")
settings = re.sub(r'uid="[^"]*"\n', "", settings)
settings = settings.replace("mitt-v1.png", "super-v2.png")
settings = settings.replace("0af2edb4121e929ab590054791392863", hashlib.md5(("res://"+relative.as_posix()).encode()).hexdigest())
target.with_suffix(".png.import").write_text(settings, encoding="utf-8", newline="\n")
profile = PROJECT / "profile"
profile.mkdir(exist_ok=True)
environment = os.environ.copy()
environment.update(APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL="")
command = [environment.get("GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"),
           "--headless", "--editor", "--path", str(PROJECT), "--import"]
with (HERE/"import.log").open("w", encoding="utf-8") as log:
    result = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT,
                            creationflags=subprocess.CREATE_NO_WINDOW, timeout=120)
assert result.returncode == 0, result.returncode
shutil.copy2(target.with_suffix(".png.import"), (ROOT/"game"/relative).with_suffix(".png.import"))
for path in (PROJECT/".godot/imported").glob("super-v2.png-*"):
    shutil.copy2(path, ROOT/"game/.godot/imported"/path.name)
original = Path(r"C:\Users\ville\.codex\generated_images\01a18419-edb9-7701-a71d-b3531b97af15\exec-24122474-9463-4503-92c2-ac98804e9f1c.png")
assert original.read_bytes() == (ROOT/"game"/relative).read_bytes()
print("SUPER_WASH_AUTOMATIC_IMPORT: isolated import passes; original PNG bytes preserved")
