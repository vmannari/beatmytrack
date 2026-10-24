"""Task-only text/binary patch and evidence, without staging concurrent work."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
CHANGED = ["game/ui/" + name + ".gd" for name in [
    "garage_page", "garage_livery_menu", "livery_tile",
    "compact_kit_thumbnail", "livery_colour_chip",
]]
NEW = ["game/ui/garage_studio_style.gd", "game/ui/garage_wash_tool.gd",
       "game/tests/test_garage_studio_polish.gd"]
NEW += [name + ".uid" for name in NEW]
NEW += ["game/assets/menu/garage/" + name for name in [
    "hose-v1.png.import", "mitt-v1.png.import", "provenance-v1.json",
]]
NEW += ["docs/GARAGE_STUDIO_POLISH_2026_10_24.md"]
NEW += ["docs/evidence/garage-studio-polish-2026-10-24/" + name for name in [
    "run_validation.ps1", "run_suite.ps1", "preview.html", "checkpoint.py", "doc-prefixes.json",
]]
BINARY = ["game/assets/menu/garage/hose-v1.png", "game/assets/menu/garage/mitt-v1.png"]


def read(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig").replace("\r\n", "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


prefixes = json.loads(read(OUT / "doc-prefixes.json"))
before = {name: read(OUT / "before" / Path(name).name) for name in CHANGED}
for name, prefix in prefixes.items():
    current = read(ROOT / name)
    assert current.count(prefix) == 1, name
    before[name] = current.replace(prefix, "", 1)
patch = []
for name in [*before, *NEW]:
    previous, current = before.get(name, ""), read(ROOT / name)
    if previous == current:
        continue
    patch.append(f"diff --git a/{name} b/{name}\n")
    if name not in before:
        patch.append("new file mode 100644\n")
    for line in difflib.unified_diff(previous.splitlines(True), current.splitlines(True),
                                     fromfile=f"a/{name}" if name in before else "/dev/null", tofile=f"b/{name}"):
        patch.append(line if line.endswith("\n") else line + "\n\\ No newline at end of file\n")
for name in BINARY:
    result = subprocess.run(["git", "diff", "--no-index", "--binary", "--", "NUL", name], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 1 and "GIT binary patch" in result.stdout, result.stderr
    patch.append(result.stdout)
checkpoint = OUT / "checkpoint.patch"
checkpoint.write_text("".join(patch), encoding="utf-8", newline="\n")
result = subprocess.run(["git", "apply", "--reverse", "--check", str(checkpoint)], cwd=ROOT, capture_output=True, text=True)
assert result.returncode == 0, result.stderr
validation = []
for receipt in sorted(OUT.glob("*/command.json")):
    item = json.loads(read(receipt))
    item["name"] = receipt.parent.name
    item["results"] = [line for line in read(receipt.parent / "console.log").splitlines() if re.search(r"\d+ (?:checks|scripts), \d+ failures", line)]
    validation.append(item)
assets = []
for name in BINARY:
    path = ROOT / name
    width, height = struct.unpack(">II", path.read_bytes()[16:24])
    assets.append({"path": name, "sha256": sha(path), "source_dimensions": [width, height], "source_bytes": path.stat().st_size,
                   "import_max_dimension": 512, "mipmaps": True})
report = {
    "date": "2026-10-24", "requirements": ["GSP01", "GSP02", "GSP03", "R01", "Q01"],
    "engine": read(ROOT / "godot-version.txt").strip(),
    "changed_files": [*CHANGED, *prefixes, *NEW, *BINARY],
    "source_sha256": {name: sha(ROOT / name) for name in [*CHANGED, *prefixes, *NEW, *BINARY]},
    "before_sha256": {name: sha(OUT / "before" / Path(name).name) for name in CHANGED},
    "checkpoint_reverse_check": "passed", "checkpoint_sha256": sha(checkpoint),
    "checkpoint_scope": "Only this presentation pass against exact task-start copies and exact added documentation prefixes. Earlier hose/newspaper/concurrent changes excluded. No staging or commit.",
    "assets": assets, "validation": validation,
    "native_capture_sha256": {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p) for p in sorted(OUT.glob("test*/*.png"))},
    "limitations": [
        "Owner appearance/feel acceptance and client reload remain. AAA is a subjective quality ambition, not a certified result.",
        "Initial 82-check trial retained three selected-part clipping failures; resize reveal and responsive card height corrected them without weakening the assertion.",
        "Initial sandbox native start failed Windows root-certificate access; isolated runs then used the host access needed by Godot.",
        "Default Python lacks Pillow; imported size/mipmap checks run in Godot. Original generated PNGs are copied byte-exactly.",
        "Desktop Compatibility and Mobile runs are not physical-device or frame-rate certification.",
        "No phone/tablet attachment check or physical-device test, APK/export/install, live mutation, purchase, deployment or owner-process restart.",
    ],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({"checkpoint_reverse_check": "passed", "validation": {v["name"]: v["results"] for v in validation}}, indent=2))
