"""Make a scoped checkpoint while preserving the shared worktree and index."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
modified = {}
for name in [
    "game/vehicle/visible_contact_audio.gd",
    "game/tests/test_collision_trace.gd",
    "scripts/probe_windows_contact_timing.ps1",
]:
    modified[name] = (OUT / "before" / name).read_text(encoding="utf-8")
# Only remove this task's inserted marker when constructing shared-doc bases.
# Later concurrent insertions therefore remain on both sides of the patch.
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    text = (ROOT / name).read_text(encoding="utf-8")
    match = re.search(r"^2026-10-23 CBT01-CBT03/R01/Q01: [^\n]+\n\n", text, re.M)
    assert match, name
    marker = match.group(0)
    if name == "AGENTS.md":
        marker = "## Compact bridge-impact timing correction (2026-10-23)\n" + marker
    assert text.count(marker) == 1
    modified[name] = text.replace(marker, "", 1)
note = "Follow-up: the owner's Compact/bridge case exposed incomplete detailed-body\ncoverage at narrow rail ends. The [Compact bridge correction](COMPACT_BRIDGE_AUDIO_2026_10_23.md)\nreproduces and removes that detection delay. The measurements below remain the\nearlier flat-wall/kerb investigation; its remaining output latency is unchanged.\n\n"
old_doc = "docs/WINDOWS_CONTACT_TIMING_2026_10_23.md"
current_doc = (ROOT / old_doc).read_text(encoding="utf-8")
assert current_doc.count(note) == 1
modified[old_doc] = current_doc.replace(note, "", 1)
new = [
    "game/tests/probe_compact_bridge_contacts.gd",
    "game/tests/probe_compact_bridge_output.gd",
    "game/tests/test_complete_contact_outline.gd",
    "scripts/review_compact_bridge_impact.py",
    "docs/COMPACT_BRIDGE_AUDIO_2026_10_23.md",
    "docs/evidence/compact-bridge-impact-2026-10-23/report.json",
    "docs/evidence/compact-bridge-impact-2026-10-23/review.json",
    "docs/evidence/compact-bridge-impact-2026-10-23/knot.json",
    "docs/evidence/compact-bridge-impact-2026-10-23/before/game/vehicle/visible_contact_audio.gd",
    "docs/evidence/compact-bridge-impact-2026-10-23/make_checkpoint.py",
]
patch = []
files = []
for relative, before in [*modified.items(), *((name, "") for name in new)]:
    after_bytes = (ROOT / relative).read_bytes()
    after = after_bytes.decode("utf-8").replace("\r\n", "\n")
    before = before.replace("\r\n", "\n")
    if before == after:
        continue
    if relative in new:
        assert not any(line.rstrip(" \t") != line for line in after.splitlines()), relative
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    if relative in new:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(
        before.splitlines(keepends=True), after.splitlines(keepends=True),
        fromfile="/dev/null" if relative in new else "a/" + relative,
        tofile="b/" + relative,
    ))
    files.append({"path": relative, "sha256": hashlib.sha256(after_bytes).hexdigest()})
target = OUT / "scoped-change.patch"
target.write_text("".join(patch), encoding="utf-8", newline="\n")
result = subprocess.run(
    ["git", "-c", "core.safecrlf=false", "apply", "--check", "--reverse", str(target)],
    cwd=ROOT, capture_output=True, text=True,
)
receipt = {
    "command": "git -c core.safecrlf=false apply --check --reverse " + str(target.relative_to(ROOT)),
    "exit_code": result.returncode, "output": result.stdout + result.stderr,
    "patch_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
    "files": files, "shared_index_modified": False,
    "production_scope": "Duplicate perimeter endpoint removal only; other changes are diagnostics/documentation.",
}
(OUT / "checkpoint.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"files": len(files), "reverse_check_exit_code": result.returncode, "output": receipt["output"]}, indent=2))
raise SystemExit(result.returncode)
