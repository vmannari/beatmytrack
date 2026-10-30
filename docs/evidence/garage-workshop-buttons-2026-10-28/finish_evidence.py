import difflib
import hashlib
import json
from pathlib import Path
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = next(p for p in EVIDENCE.parents if (p / "godot-version.txt").exists())
files = {
    "game/ui/garage_page.gd": "garage_page.before.gd.txt",
    "game/tests/test_garage_clean_customisation.gd": "test_garage_clean_customisation.before.gd.txt",
    "game/tests/test_garage_sidebar.gd": "test_garage_sidebar.before.gd.txt",
}
patch = ""
hashes = {}
scratch = ROOT / "build/garage-workshop-buttons-checkpoint"
for path, original in files.items():
    before = (EVIDENCE / original).read_text(encoding="utf-8-sig")
    after = (ROOT / path).read_text(encoding="utf-8-sig")
    patch += "diff --git a/" + path + " b/" + path + "\n"
    patch += "".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), "a/"+path, "b/"+path))
    hashes[path] = {"before_sha256": hashlib.sha256((EVIDENCE / original).read_bytes()).hexdigest(),
                    "after_sha256": hashlib.sha256((ROOT / path).read_bytes()).hexdigest()}
    target = scratch / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(before, encoding="utf-8", newline="")
patch_path = EVIDENCE / "task.patch"
patch_path.write_text(patch, encoding="utf-8", newline="")
checks = []
for command in [
    ["git", "apply", "--check", "--reverse", "--whitespace=nowarn", str(patch_path)],
    ["git", "apply", "--check", "--whitespace=nowarn", "--directory=build/garage-workshop-buttons-checkpoint", str(patch_path)],
    ["git", "diff", "--check", "--", *files],
]:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    checks.append({"command": command, "exit_code": result.returncode, "output": result.stdout + result.stderr})
commands = {p.parent.name: json.loads(p.read_text(encoding="utf-8")) for p in EVIDENCE.glob("*/command.json")}
reports = {p.parent.name: json.loads(p.read_text(encoding="utf-8")) for name in ["report.json", "layout.json"] for p in EVIDENCE.glob("*/" + name)}
report = {
    "requirements": ["GWB01", "GWB02", "GWB03"],
    "runtime_files": ["game/ui/garage_page.gd"],
    "hashes": hashes,
    "commands": commands,
    "test_reports": reports,
    "checkpoint_checks": checks,
    "known_failure": "forklift heavy slow film still blocks; also fails with exact task-start Garage source",
    "physical_device_test": False,
    "apk_export_or_deployment": False,
    "screenshots": [str(p.relative_to(EVIDENCE)).replace("\\", "/") for p in EVIDENCE.glob("*/*.png")],
}
if (EVIDENCE / "metadata-restoration.json").exists():
    report["metadata_restoration"] = json.loads((EVIDENCE / "metadata-restoration.json").read_text(encoding="utf-8"))
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({"checkpoint_checks": [{"exit_code": row["exit_code"]} for row in checks],
                  "test_reports": {name: {key: value.get(key) for key in ["checks", "failures", "renderer"]} for name, value in reports.items()}}, indent=2))
if any(row["exit_code"] for row in checks):
    raise SystemExit(1)
