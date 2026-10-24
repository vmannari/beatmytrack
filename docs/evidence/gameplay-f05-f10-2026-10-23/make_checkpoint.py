"""Recreate this task's text-only review checkpoint; never edit Git's index."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
before = {row["path"]: row for row in json.loads((EVIDENCE / "before.json").read_text(encoding="utf-8-sig"))}
for name, row in before.items():
    assert hashlib.sha256((EVIDENCE / "before" / name.replace("/", "__")).read_bytes()).hexdigest() == row["sha256"], name

production = [
    "game/core/game.gd", "game/race/rewind_history.gd", "game/track/creator_prop_visual.gd",
    "game/track/native_track_visual.gd", "game/track/spatial_mesh_chunks.gd",
    "game/track/night_fire_volume.gdshader", "game/track/night_prop_effects.gd",
    "game/track/night_render_preparation.gd", "game/track/night_light_budget.gd",
]
tests = ["test_compact_rewind", "profile_compact_rewind", "profile_gameplay_fire", "profile_gameplay_textures",
         "profile_gameplay_prop_chunks", "test_gameplay_render_envelope", "test_gameplay_runtime_lifecycle",
         "test_gameplay_texture_compression"]
paths = production + ["game/tests/" + name + ".gd" for name in tests]
paths += [name + ".uid" for name in paths if name.endswith(".gd") and name not in before and (ROOT / (name + ".uid")).exists()]
metrics = json.loads((EVIDENCE / "summary-metrics.json").read_text())
paths += ["game/assets/textures/" + name + ".png.import" for name in metrics["textures"]["names"]]
paths += ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "docs/GAMEPLAY_AUDIT_2026_10_23.md", "docs/GAMEPLAY_F05_F10_2026_10_23.md"]
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT / "game/tests/fixtures/gameplay_f05_f10_before").iterdir() if p.is_file()]
prefixes = json.loads((EVIDENCE / "document-prefixes.json").read_text())
followup = ("Follow-up: F05–F10 are implemented and revalidated locally. Whole-prop spatial draws, bounded Night lights/fire work, "
            "compressed artwork and compact exact rewind snapshots are documented in [GAMEPLAY_F05_F10_2026_10_23.md](GAMEPLAY_F05_F10_2026_10_23.md), "
            "with native comparisons and remaining Android acceptance. The findings below retain the audit-time state.\n\n")
patch = []
manifest = []
for name in paths:
    path = ROOT / name
    after = path.read_text(encoding="utf-8-sig")
    old = None
    if name in prefixes:
        assert after.count(prefixes[name]) == 1, name
        old = after.replace(prefixes[name], "", 1)
    elif name == "docs/GAMEPLAY_AUDIT_2026_10_23.md":
        assert after.count(followup) == 1
        old = after.replace(followup, "", 1)
        assert old == (EVIDENCE / "before" / name.replace("/", "__")).read_text(encoding="utf-8-sig")
    elif name == "game/track/creator_prop_visual.gd":
        # Concurrent biome preparation changed this file after task start.
        # Remove only our assembly metadata to form its effective baseline.
        owned = (
            '\tif kind in PropWinterCraft.KINDS or kind in PropEgypt.KINDS or kind in PropNight.KINDS:\n'
            "\t\t# Keep a building's overlapping trim in its original triangle order inside\n"
            '\t\t# one spatial draw. These are triangle-corner ends, before hidden pruning.\n'
            '\t\tvar ends: PackedInt32Array = tool.get_meta("spatial_object_ends",PackedInt32Array())\n'
            '\t\tvar centres: PackedVector3Array = tool.get_meta("spatial_object_centres",PackedVector3Array())\n'
            '\t\tends.append(int(tool.get_meta("prop_triangle_count"))*3); centres.append(center)\n'
            '\t\ttool.set_meta("spatial_object_ends",ends); tool.set_meta("spatial_object_centres",centres)\n'
        )
        assert after.count(owned) == 1
        old = after.replace(owned, "", 1)
    elif name in before:
        old = (EVIDENCE / "before" / name.replace("/", "__")).read_text(encoding="utf-8-sig")
    if old == after:
        continue
    if old is not None:
        target = EVIDENCE / "checkpoint-before" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(old, encoding="utf-8")
    patch.append(f"diff --git a/{name} b/{name}\n")
    if old is None:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff((old or "").splitlines(True), after.splitlines(True),
                                    fromfile="a/" + name if old is not None else "/dev/null", tofile="b/" + name))
    manifest.append({"path": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "new": old is None,
                     "baseline_sha256": hashlib.sha256(old.encode()).hexdigest() if old is not None else None})
(EVIDENCE / "task-only.patch").write_bytes("".join(patch).encode("utf-8"))
(EVIDENCE / "source-manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
masters = []
for name in metrics["textures"]["names"]:
    path = "game/assets/textures/" + name + ".png"
    working = subprocess.check_output(["git", "hash-object", path], cwd=ROOT, text=True).strip()
    original = subprocess.check_output(["git", "rev-parse", "HEAD:" + path], cwd=ROOT, text=True).strip()
    assert original == working, path
    masters.append({"path": path, "sha256": hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), "unchanged_git_blob": working})
(EVIDENCE / "png-masters.json").write_text(json.dumps(masters, indent=2) + "\n")
print(f"Checkpoint: {len(manifest)} files, {(EVIDENCE / 'task-only.patch').stat().st_size} bytes; {len(before)} exact backups, {len(masters)} unchanged PNGs.")
