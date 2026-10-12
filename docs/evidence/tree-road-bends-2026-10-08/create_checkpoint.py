"""Task-only Git patch; preserve concurrent work and leave the index untouched."""
from pathlib import Path
import difflib
import hashlib
import json

out = Path(__file__).resolve().parent
root = out.parents[2]
changed = ["game/track/visual_road_join.gd", "game/track/native_track_visual.gd"]
new = ["game/tests/test_tree_road_bends.gd", "game/tests/test_tree_road_bends.gd.uid",
       "game/tests/fixtures/to_the_trees.json", "docs/TREE_ROAD_BENDS.md"]
baseline = {name: (out / "before" / name).read_text(encoding="utf-8") for name in changed}
baseline.update({name: "" for name in new})
invocation = "    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_tree_road_bends.gd') 'tree-road-bend-tests.log'\n"
current_dev = (root / "scripts/dev.ps1").read_text(encoding="utf-8")
assert current_dev.count(invocation) == 1
baseline["scripts/dev.ps1"] = current_dev.replace(invocation, "", 1)
for name in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    after = (root / name).read_text(encoding="utf-8")
    paragraphs = after.split("\n\n")
    own = [entry for entry in paragraphs if "docs/TREE_ROAD_BENDS.md" in entry]
    assert len(own) == 1
    baseline[name] = after.replace(own[0] + "\n\n", "", 1)
patch, hashes = [], {}
for name, before in baseline.items():
    after = (root / name).read_text(encoding="utf-8")
    patch.append(f"diff --git a/{name} b/{name}\n")
    if not before:
        patch.append("new file mode 100644\n")
    for line in difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                    fromfile="a/" + name if before else "/dev/null", tofile="b/" + name):
        patch.append(line if line.endswith("\n") else line + "\n\\ No newline at end of file\n")
    hashes[name] = {"before_normalized_sha256": hashlib.sha256(before.encode()).hexdigest(),
                    "after_normalized_sha256": hashlib.sha256(after.encode()).hexdigest()}
(out / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(out / "source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
print(f"TREE_BEND_CHECKPOINT: {len(baseline)} files; Git index untouched")
