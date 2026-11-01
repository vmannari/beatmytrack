"""Copy one privately baked common preview set into both probe projects."""
import json
import shutil
import subprocess
import sys

import prepare as p


def main() -> None:
    task, base = p.TASK, p.BASE
    provenance = json.loads((task / "provenance.json").read_text(encoding="utf-8"))
    if "common_bake" in provenance:
        raise SystemExit("Common preview bake was already finalized; refusing to overwrite provenance")
    before = json.loads((task / "snapshot-sha256.json").read_text(encoding="utf-8"))
    after = p.inventory(base)
    changed = {path for path in before if before[path] != after.get(path)}
    added = set(after) - set(before)
    if any(not path.startswith("game/assets/garage/previews_v1/") for path in changed):
        raise SystemExit(f"Unexpected source changes during private bake: {sorted(changed)}")
    if any(not path.endswith(".uid") for path in added):
        raise SystemExit(f"Unexpected generated files during private bake: {sorted(added)}")
    if set(before) - set(after):
        raise SystemExit("Snapshot lost files during private bake")
    check = subprocess.run([sys.executable, str(base / "scripts/check_garage_previews.py")], capture_output=True, text=True)
    if check.returncode:
        raise SystemExit("Private common preview check failed:\n" + check.stderr)
    for name in ("compatibility", "mobile"):
        variant = task / name
        prior = p.inventory(variant)
        expected_before = ["game/export_presets.cfg"] + (["game/project.godot"] if name == "mobile" else [])
        if set(prior) != set(before) or [path for path in before if before[path] != prior[path]] != expected_before:
            raise SystemExit(f"{name} variant changed before the common bake was applied")
        for path in sorted(changed | added):
            destination = variant / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(base / path, destination)
        final = p.inventory(variant)
        if set(final) != set(after) or [path for path in after if after[path] != final[path]] != expected_before:
            raise SystemExit(f"{name} variant differs beyond package/renderer settings")
        check = subprocess.run([sys.executable, str(variant / "scripts/check_garage_previews.py")], capture_output=True, text=True)
        if check.returncode:
            raise SystemExit(f"{name} preview check failed:\n{check.stderr}")
        print(name, check.stdout.strip())
    (task / "snapshot-before-common-bake-sha256.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
    (task / "snapshot-sha256.json").write_text(json.dumps(after, indent=2), encoding="utf-8")
    provenance["common_bake"] = {"changed_files": sorted(changed), "generated_uids": sorted(added),
                                  "preview_check": "passed in both variants; see bake log for engine/renderer"}
    (task / "provenance.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")
    print("COMMON_PREVIEWS_FINALIZED")


if __name__ == "__main__":
    main()
