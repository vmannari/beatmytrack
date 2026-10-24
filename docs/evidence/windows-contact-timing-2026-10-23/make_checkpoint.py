"""Create a task-only text patch without changing the shared Git index."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
modified = {
    "game/tests/probe_direct_collision_output.gd": (OUT / "before/game/tests/probe_direct_collision_output.gd").read_bytes(),
}
reviewer = "scripts/review_direct_collision_output.py"
modified[reviewer] = subprocess.run(
    ["git", "show", "HEAD:" + reviewer], cwd=ROOT, capture_output=True, check=True
).stdout
for relative in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    modified[relative] = (OUT / "doc-base" / relative).read_bytes()
new = [
    "game/tests/probe_kerb_contact_output.gd",
    "scripts/probe_windows_contact_timing.ps1",
    "scripts/review_kerb_contact_output.py",
    "docs/WINDOWS_CONTACT_TIMING_2026_10_23.md",
    "docs/evidence/windows-contact-timing-2026-10-23/report.json",
    "docs/evidence/windows-contact-timing-2026-10-23/runtime-unchanged.json",
    "docs/evidence/windows-contact-timing-2026-10-23/make_checkpoint.py",
]
patch = []
files = []
for relative, before in [*modified.items(), *((relative, b"") for relative in new)]:
    after = (ROOT / relative).read_bytes()
    before_text = before.decode("utf-8").replace("\r\n", "\n")
    after_text = after.decode("utf-8").replace("\r\n", "\n")
    if before_text == after_text:
        continue
    if relative in new:
        assert not any(line.rstrip(" \t") != line for line in after_text.splitlines()), relative
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    if relative in new:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(
        before_text.splitlines(keepends=True), after_text.splitlines(keepends=True),
        fromfile="/dev/null" if relative in new else "a/" + relative,
        tofile="b/" + relative,
    ))
    files.append({"path": relative, "sha256": hashlib.sha256(after).hexdigest()})
target = OUT / "scoped-change.patch"
target.write_text("".join(patch), encoding="utf-8", newline="\n")
result = subprocess.run(
    ["git", "-c", "core.safecrlf=false", "apply", "--check", "--reverse", str(target)],
    cwd=ROOT, capture_output=True, text=True,
)
receipt = {
    "command": "git -c core.safecrlf=false apply --check --reverse " + str(target.relative_to(ROOT)),
    "exit_code": result.returncode,
    "output": result.stdout + result.stderr,
    "patch_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
    "files": files,
    "shared_index_modified": False,
    "runtime_fix_claimed": False,
}
(OUT / "checkpoint.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"files": len(files), "reverse_check_exit_code": result.returncode, "output": receipt["output"]}, indent=2))
raise SystemExit(result.returncode)
