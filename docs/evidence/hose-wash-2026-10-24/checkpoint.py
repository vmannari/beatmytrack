"""Record the hose slice without staging, committing or including concurrent work."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
RUNTIME = [
    "game/ui/car_showroom.gd", "game/ui/garage_page.gd",
    "game/ui/garage_wash_effect.gd", "game/ui/garage_wash_geometry.gd",
    "game/vehicle/vehicle_weathering.gd",
]
NEW = [
    "game/tests/test_garage_hose.gd", "game/tests/test_garage_hose.gd.uid",
    "docs/GARAGE_HOSE_2026_10_24.md",
    "docs/evidence/hose-wash-2026-10-24/run_validation.ps1",
    "docs/evidence/hose-wash-2026-10-24/run_baseline.ps1",
    "docs/evidence/hose-wash-2026-10-24/checkpoint.py",
    "docs/evidence/hose-wash-2026-10-24/doc-prefixes.json",
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig").replace("\r\n", "\n")


prefixes = json.loads(read(OUT / "doc-prefixes.json"))
originals = {name: read(OUT / "before" / name) for name in RUNTIME}
for name, prefix in prefixes.items():
    current = read(ROOT / name)
    assert current.count(prefix) == 1, name
    originals[name] = current.replace(prefix, "", 1)

patch = []
for name in [*originals, *NEW]:
    previous = originals.get(name, "")
    current = read(ROOT / name)
    if previous == current:
        continue
    patch.append(f"diff --git a/{name} b/{name}\n")
    if name not in originals:
        patch.append("new file mode 100644\n")
    difference = difflib.unified_diff(
        previous.splitlines(True), current.splitlines(True),
        fromfile=f"a/{name}" if name in originals else "/dev/null",
        tofile=f"b/{name}",
    )
    for line in difference:
        patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
(OUT / "checkpoint.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
verified = subprocess.run(
    ["git", "apply", "--reverse", "--check", str(OUT / "checkpoint.patch")],
    cwd=ROOT, text=True, capture_output=True, check=False,
)
assert verified.returncode == 0, verified.stderr

validation = []
for receipt in sorted(OUT.glob("*/command.json")):
    entry = json.loads(read(receipt))
    log = read(receipt.parent / "console.log")
    entry["name"] = receipt.parent.name
    entry["console"] = str((receipt.parent / "console.log").relative_to(ROOT)).replace("\\", "/")
    entry["result"] = [line for line in log.splitlines() if re.search(r"\d+ (?:checks|scripts), \d+ failures", line)]
    validation.append(entry)
baseline = json.loads(read(OUT / "baseline-animation-command.json"))
baseline["result"] = [line for line in read(OUT / "baseline-animation.log").splitlines() if "checks," in line]
images = {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p) for p in sorted(OUT.glob("test_garage_hose-*/*.png"))}
report = {
    "date": "2026-10-24", "requirements": ["HWS01", "HWS02", "HWS03", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "changed_files": [*RUNTIME, *prefixes, *NEW],
    "source_sha256": {name: sha(ROOT / name) for name in [*RUNTIME, *prefixes, *NEW]},
    "before_sha256": {name: sha(OUT / "before" / name) for name in RUNTIME},
    "checkpoint_sha256": sha(OUT / "checkpoint.patch"),
    "checkpoint_reverse_check": "passed",
    "checkpoint_scope": "Five task-start runtime copies and this task's exact document prefixes; concurrent source/document changes and generated build identities excluded. No staging or commit.",
    "tuning": {"hose_radius": 0.72, "film_rate": 1.60, "primary_grime_rate": 0.025, "unchanged_mitt_rate": 1.15, "jet_slots": 12, "existing_water_slots": 32},
    "validation": validation,
    "baseline_animation": baseline,
    "import": {"command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 240", "log": "docs/evidence/hose-wash-2026-10-24/import.log", "exit_code": 0},
    "native_images_sha256": images,
    "limitations": [
        "Owner washing-effort and appearance acceptance remains; reload the client.",
        "Existing animation restart assertion fails once in 139 checks, identically with task-start runtime sources. Assertions unchanged.",
        "Initial sandbox certificate-store failure and a later concurrent Desert ROOTS parser interruption retained; normal Windows access and the unchanged rerun succeed.",
        "No phone/tablet attachment check or physical-device test, APK/export/install, native rebuild, owner-process restart, live mutation, purchase or deployment.",
        "Desktop renderer checks do not establish phone fragment cost, thermal behavior or touch feel.",
    ],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False)+"\n", encoding="utf-8", newline="\n")
print(json.dumps({"checkpoint_reverse_check": "passed", "validation_results": {v["name"]: v["result"] for v in validation}, "images": len(images)}, indent=2))
