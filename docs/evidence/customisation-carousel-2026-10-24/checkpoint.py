"""Build a task-only patch and evidence manifest without staging concurrent work."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
SOURCES = [
    "game/ui/garage_page.gd", "game/ui/garage_livery_menu.gd",
    "game/ui/garage_cosmetic_shelf.gd", "game/ui/garage_cosmetic_shelf.gd.uid",
    "game/ui/garage_part_highlight.gd", "game/ui/garage_part_highlight.gd.uid",
    "game/ui/garage_part_highlight.gdshader", "game/ui/garage_part_highlight.gdshader.uid",
    "game/tests/test_customisation_carousel.gd", "game/tests/test_customisation_carousel.gd.uid",
    "docs/CUSTOMISATION_CAROUSEL_2026_10_24.md",
    "docs/evidence/customisation-carousel-2026-10-24/run.ps1",
    "docs/evidence/customisation-carousel-2026-10-24/preview.html",
    "docs/evidence/customisation-carousel-2026-10-24/checkpoint.py",
    "AGENTS.md", "DEVELOPMENT_STATUS.md",
]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read_log(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig", errors="replace")

patch = []
for name in SOURCES:
    current = (ROOT / name).read_text(encoding="utf-8-sig")
    previous = BASE / "before" / name.replace("/", "__")
    if name in ("AGENTS.md", "DEVELOPMENT_STATUS.md"):
        prefix = re.search(r"<!-- CUSTOMISATION-CAROUSEL-20261024 -->.*?<!-- /CUSTOMISATION-CAROUSEL-20261024 -->\n\n", current, re.S)
        if prefix is None:
            raise RuntimeError(f"Missing exact task documentation prefix: {name}")
        old = current[:prefix.start()] + current[prefix.end():]
    else:
        old = previous.read_text(encoding="utf-8-sig") if previous.exists() else ""
    if old == current:
        continue
    patch.append(f"diff --git a/{name} b/{name}\n")
    if not previous.exists() and name not in ("AGENTS.md", "DEVELOPMENT_STATUS.md"):
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(old.splitlines(True), current.splitlines(True), fromfile=f"a/{name}" if old else "/dev/null", tofile=f"b/{name}"))
checkpoint = BASE / "checkpoint.patch"
checkpoint.write_text("".join(patch), encoding="utf-8", newline="\n")
verified = subprocess.run(["git", "apply", "--reverse", "--check", "--whitespace=error", str(checkpoint)], cwd=ROOT, capture_output=True, text=True)
if verified.returncode:
    raise RuntimeError(verified.stderr)

validation = []
for command in sorted(BASE.glob("*/command.json")):
    value = json.loads(command.read_text(encoding="utf-8-sig"))
    console = read_log(command.with_name("console.log"))
    value["name"] = command.parent.name
    value["results"] = [line for line in console.splitlines() if re.search(r"\d+ checks, \d+ failures|SCRIPT_PARSE:", line)]
    validation.append(value)

report = {
    "date": "2026-10-24", "requirements": ["CCP01", "CCP02", "CCP03", "CCP04", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "changed_files": SOURCES,
    "source_sha256": {name: digest(ROOT / name) for name in SOURCES},
    "before_sha256": {str(path.relative_to(BASE)): digest(path) for path in (BASE / "before").glob("*")},
    "validation": validation,
    "supplemental_validation": [
        {"name":"pinned headless import", "environment":{"APPDATA":str(ROOT / "build/customisation-carousel-2026-10-24/import/user")},
         "arguments":["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "Import", "-CommandTimeoutSeconds", "180"], "exit_code":0, "log":"import.log"},
        {"name":"task patch whitespace", "arguments":["git", "apply", "--reverse", "--check", "--whitespace=error", str(checkpoint)], "result":"checked by checkpoint generation"},
    ],
    "captures_sha256": {str(path.relative_to(BASE)): digest(path) for path in sorted(BASE.rglob("*.png"))},
    "checkpoint_reverse_check": "passed", "checkpoint_sha256": digest(checkpoint),
    "checkpoint_scope": "Task-start source copies and exact task documentation prefixes only; no staging, commit or concurrent changes. Native captures are retained separately and hashed.",
    "prior_native_baseline": {
        "source": "docs/evidence/garage-studio-polish-2026-10-24/test_garage_studio_polish-gl_compatibility",
        "source_identity": "Task-start GaragePage and GarageLiveryMenu hashes exactly match the preceding report's final source hashes. Before PNGs are copied byte-for-byte.",
    },
    "initial_corrections": ["sandbox certificate-store denial", "null button callback", "missing metadata default", "960x540 full-App footer overflow", "preview cleanup after detachment", "detail camera used world_3d instead of effective world", "deferred shelf layout after removal"],
    "limits": ["Owner appearance and touch acceptance remain; reload required", "Desktop GPU renderers only; no physical-device performance claim", "No attachment check, physical-device test, APK, actual purchase, live mutation, deployment or owner-process restart", "Old two-column layout fixture is unchanged and explicitly superseded by requested carousel"],
}
(BASE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print("CUSTOMISATION_CHECKPOINT: reverse check passed;", len(SOURCES), "task files;", len(validation), "validation records")
