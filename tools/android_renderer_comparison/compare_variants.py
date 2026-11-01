"""Check source-tree parity after both isolated builds; this is not APK parity."""
import json
from pathlib import Path

import prepare


def main():
    task = prepare.TASK
    before = prepare.inventory(task / "compatibility")
    after = prepare.inventory(task / "mobile")
    changed = sorted(path for path in set(before) | set(after) if before.get(path) != after.get(path))
    allowed = {"game/project.godot", "game/export_presets.cfg", "game/core/build_identity.gd"}
    unexpected = sorted(set(changed) - allowed)
    output = {"changed": changed, "allowed": sorted(allowed), "unexpected": unexpected,
              "limitation": "Source-tree comparison only; APK contents, runtime renderer and visual parity need separate checks."}
    (task / "post-build-source-comparison.json").write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(json.dumps(output, indent=2))
    if unexpected:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
