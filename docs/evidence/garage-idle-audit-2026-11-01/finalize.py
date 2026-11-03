"""Record the scoped Garage idle fixes; use only an isolated checkpoint index."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import uuid

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(folder, *args):
    return subprocess.run(["git", "-C", str(folder), *args], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout

def log_text(name):
    raw = (OUT / "logs" / (name + ".log")).read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig", errors="replace")

summary = (
    "<!-- GARAGE-IDLE-AUDIT-20261101 -->\n"
    "## Other Garage elements audited for unnecessary drawing (2026-11-01)\n"
    "GIA01-GIA04: Off-camera snow no longer redraws the room after material preparation; melting and reflected-only visibility remain. Stationary wash cursors reuse drawing commands, and washing empty space submits no invisible-feedback draws. All eight sections settle; both desktop renderers48/0, hose81/0 and wash surfaces45/0 pass. Original washing139/4 reproduces with task-start sources. Exact cursor/room/five-car retained pixels pass; two runtime sources only. Commands, native views, first highlight-preparation correction and scoped checkpoint: [docs/GARAGE_IDLE_AUDIT_2026_11_01.md](docs/GARAGE_IDLE_AUDIT_2026_11_01.md). Tablet/owner acceptance and FPS remain unmeasured. No device query/test, APK, owner-save/process mutation, live/backend access, deployment or main-index write; concurrent work preserved.\n"
    "<!-- /GARAGE-IDLE-AUDIT-20261101 -->\n\n"
).encode("utf-8")
before_map = {}
for relative in ("AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
    target = ROOT / relative
    archived = OUT / "before" / ("PHASE_0_PLAN.md" if relative.startswith("docs/") else relative)
    data = target.read_bytes()
    if b"<!-- GARAGE-IDLE-AUDIT-20261101 -->" not in data:
        archived.write_bytes(data)
        block = summary.replace(b"docs/GARAGE_IDLE_AUDIT_2026_11_01.md", b"GARAGE_IDLE_AUDIT_2026_11_01.md") if relative.startswith("docs/") else summary
        target.write_bytes(block + data)
    before_map[relative] = archived

for relative in ("game/ui/car_showroom.gd", "game/ui/garage_wash_effect.gd"):
    before_map[relative] = OUT / "before" / relative
new = ["docs/GARAGE_IDLE_AUDIT_2026_11_01.md", "game/tests/test_garage_idle_elements.gd", "game/tests/probe_garage_wash_idle_control.gd"]
files = list(before_map) + new
index_before = sha(ROOT / ".git/index")
scratch = ROOT / "build" / ("garage-idle-checkpoint-" + uuid.uuid4().hex[:8])
scratch.mkdir()
git(scratch, "init", "-q")
git(scratch, "config", "core.autocrlf", "false")
for relative, source in before_map.items():
    target = scratch / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
git(scratch, "add", ".")
for relative in files:
    target = scratch / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / relative, target)
git(scratch, "add", "-N", *new)
patch = OUT / "task.patch"
patch.write_bytes(git(scratch, "diff", "--binary", "--full-index", "--no-ext-diff"))
git(scratch, "apply", "--check", "--reverse", str(patch))
git(scratch, "apply", "--reverse", str(patch))
assert all((scratch / relative).read_bytes() == source.read_bytes() for relative, source in before_map.items())
git(scratch, "apply", "--check", str(patch))
git(scratch, "apply", str(patch))
assert all((scratch / relative).read_bytes() == (ROOT / relative).read_bytes() for relative in files)
assert sha(ROOT / ".git/index") == index_before

tests = {}
for name in ("control", "control-mobile", "final-settled-gl", "final-settled-mobile", "wash-animation-gl", "wash-animation-control", "hose", "wash-surfaces"):
    tests[name] = [line for line in log_text(name).splitlines() if re.search(r"\d+ checks.*\d+ failures", line)]
profiles = {renderer: json.loads((OUT / "after" / renderer / "report.json").read_text()) for renderer in ("gl_compatibility", "mobile")}
assert all(profile["checks"] == 48 and profile["failures"] == 0 for profile in profiles.values())
report = {
    "date": "2026-11-01", "requirements": ["GIA01", "GIA02", "GIA03", "GIA04"],
    "control": json.loads((OUT / "control/report.json").read_text()),
    "profiles": profiles, "tests": tests,
    "files": {relative: {"sha256": sha(ROOT / relative), **({"before_sha256": sha(before_map[relative])} if relative in before_map else {})} for relative in files},
    "checkpoint": {"files": len(files), "sha256": sha(patch), "forward_check": True, "reverse_check": True,
                   "exact_content_round_trip": True, "main_index_unchanged": index_before, "scratch": str(scratch.relative_to(ROOT))},
    "limitations": ["Desktop render counters, not physical-tablet FPS", "No device query/test or APK/deployment",
                    "Four unchanged washing-animation fixture failures reproduce in task-start control",
                    "Page layout/condition polling remains a CPU profiling target", "Owner appearance and device acceptance remain"],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"tests": tests, "checkpoint_files": len(files), "checkpoint_round_trip": True, "main_index_unchanged": True}, indent=2))
