"""Capture this follow-up against its saved pre-change sources, retaining shared work."""
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def section(value, start, end):
    a = value.index(start)
    return value[a:value.index(end, a)]


patches, manifest = [], []
paths = sorted(path.relative_to(OUT / "before").as_posix() for path in (OUT / "before").rglob("*") if path.is_file())
paths += ["game/race/race_incidents.gd", "game/race/race_incidents.gd.uid"]
for path in paths:
    if not (ROOT / path).exists():
        continue
    current = (ROOT / path).read_text(encoding="utf-8").replace("\r\n", "\n")
    saved = OUT / "before" / path
    original = saved.read_text(encoding="utf-8").replace("\r\n", "\n") if saved.exists() else ""
    if path == "game/ui/garage_page.gd":
        # Concurrent News layout changes happened after the snapshot. Preserve
        # those in the patch basis; only currency functions belong to this task.
        basis = current
        for start, end in [("func _shop_changed()", "func _shop_badge("),
                           ("func _require_owned(", "func _new_menu_panels()")]:
            basis = basis.replace(section(basis, start, end), section(original, start, end), 1)
        original = basis
    if original == current:
        continue
    patches.append(f"diff --git a/{path} b/{path}\n")
    if not saved.exists():
        patches.append("new file mode 100644\n")
    patches.extend(difflib.unified_diff(original.splitlines(True), current.splitlines(True),
        fromfile="a/" + path if saved.exists() else "/dev/null", tofile="b/" + path))
    manifest.append({"path": path, "sha256": hashlib.sha256((ROOT / path).read_bytes()).hexdigest(),
                     "before_lf_sha256": hashlib.sha256(original.encode()).hexdigest()})
(OUT / "task.patch").write_text("".join(patches), encoding="utf-8", newline="\n")
(OUT / "source-manifest.json").write_text(json.dumps({
    "basis": "Follow-up snapshots, with concurrent Garage News layout changes retained in both sides",
    "files": manifest}, indent=2) + "\n", encoding="utf-8")
print(f"Follow-up checkpoint: {len(manifest)} sources/contracts")
