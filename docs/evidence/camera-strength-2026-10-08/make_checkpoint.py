"""Retain only this camera task's delta, preserving concurrent workspace work."""
from pathlib import Path
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
FILES = [
    "game/camera/camera_profile.gd",
    "game/camera/follow_camera.gd",
    "game/core/game.gd",
    "game/persistence/local_records.gd",
    "game/ui/settings_page.gd",
    "game/ui/race_pause_menu.gd",
    "game/tests/test_camera_modes.gd",
    "game/tests/capture_camera_modes.gd",
    "game/tests/capture_settings.gd",
    "docs/CAMERA_OPTIONS.md",
    "DEVELOPMENT_STATUS.md",
    "docs/PHASE_0_PLAN.md",
    "AGENTS.md",
]
STATUS_PREFIXES = {
    "DEVELOPMENT_STATUS.md": "2026-10-08 V01/V03-V05/Q01: owner-requested stronger/configurable",
    "docs/PHASE_0_PLAN.md": "2026-10-08 V01/V03-V05/Q01: stronger configurable",
}

patch = []
hashes = {}
for name in FILES:
    current = (ROOT / name).read_text(encoding="utf-8-sig")
    original = (EVIDENCE / "before" / name).read_text(encoding="utf-8-sig")
    baseline_kind = "task_start"
    if name in STATUS_PREFIXES:
        lines = current.splitlines(keepends=True)
        indices = [i for i, line in enumerate(lines) if line.startswith(STATUS_PREFIXES[name])]
        assert len(indices) == 1, name
        index = indices[0]
        lines.pop(index)
        if index < len(lines) and not lines[index].strip():
            lines.pop(index)
        original = "".join(lines)
        baseline_kind = "current_without_camera_entry"
    elif name == "AGENTS.md":
        marker = "\n## Stronger configurable speed zoom override (2026-10-08)\n"
        start = current.index(marker)
        end = current.find("\n## ", start + len(marker))
        original = current[:start].rstrip() + "\n" + (current[end:] if end != -1 else "")
        baseline_kind = "current_without_camera_override"
    baseline_path = EVIDENCE / "checkpoint-base" / name
    baseline_path.parent.mkdir(parents=True, exist_ok=True)
    baseline_path.write_text(original, encoding="utf-8", newline="\n")
    patch.extend(difflib.unified_diff(
        original.splitlines(keepends=True), current.splitlines(keepends=True),
        fromfile="a/" + name, tofile="b/" + name,
    ))
    hashes[name] = {
        "baseline_kind": baseline_kind,
        "baseline_sha256_lf": hashlib.sha256(original.encode()).hexdigest(),
        "current_sha256_lf": hashlib.sha256(current.encode()).hexdigest(),
    }

(EVIDENCE / "camera-strength.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(EVIDENCE / "source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
print(f"Saved scoped patch and hashes for {len(FILES)} camera task files.")
