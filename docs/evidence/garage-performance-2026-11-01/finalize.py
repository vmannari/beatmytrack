"""Record this task's evidence and checkpoint without touching the main index."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(folder, *args):
    return subprocess.run(["git", "-C", str(folder), *args], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout

provenance_path = ROOT / "game/assets/garage/workshop_v1.provenance.json"
provenance = json.loads(provenance_path.read_text(encoding="utf-8-sig"))
provenance["scene_sha256"] = sha(ROOT / "game/assets/garage/workshop_v1.scn")
provenance["sources"]["tests/support/garage_mesh_lods.gd"] = sha(ROOT / "game/tests/support/garage_mesh_lods.gd")
provenance["lod_generator"] = "res://tests/support/garage_mesh_lods.gd"
provenance["lod_validation"] = "Original GPU surface buffers retained exactly; native half-pixel LOD comparisons and both-renderer regression in docs/GARAGE_PERFORMANCE_2026_11_01.md."
provenance_path.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n", encoding="utf-8")

marker = b"<!-- GARAGE-PERFORMANCE-20261101 -->"
summary = (
    "<!-- GARAGE-PERFORMANCE-20261101 -->\n"
    "## Garage rendering and model optimisation (2026-11-01)\n"
    "GPO01-GPO04: Off-camera playing records no longer redraw the Garage; phase and visible/reflection-only animation remain. Offline half-pixel LOD indices retain original GPU vertex buffers/full-detail geometry; layered Hover and all glazing stay full detail after a rejected canopy trial. Five-car main-view triangles fall25.72-45.09%; rotating component all-pass triangles fall25.08%. Both desktop renderers1589/0, washing45/0 and App menu35/0 pass; kit2424/3 reproduces with task-start sources/assets. Thirty native image pairs include maximum zoom; maximum mean RGB difference0.051605/255 and canopy region exact. Commands, views, memory/package tradeoff and scoped binary checkpoint: [docs/GARAGE_PERFORMANCE_2026_11_01.md](docs/GARAGE_PERFORMANCE_2026_11_01.md). Tablet/owner appearance, FPS and cold-start acceptance remain; no device query/test, APK, owner-save/process change, live mutation, deployment or main-index write. Concurrent work preserved.\n"
    "<!-- /GARAGE-PERFORMANCE-20261101 -->\n\n"
).encode("utf-8")
for relative in ("AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
    target = ROOT / relative
    data = target.read_bytes()
    block = summary
    if relative.startswith("docs/"):
        block = summary.replace(b"docs/GARAGE_PERFORMANCE_2026_11_01.md", b"GARAGE_PERFORMANCE_2026_11_01.md")
    if marker not in data:
        target.write_bytes(block + data)
    else:
        end = data.index(b"<!-- /GARAGE-PERFORMANCE-20261101 -->") + len(b"<!-- /GARAGE-PERFORMANCE-20261101 -->")
        target.write_bytes(block.rstrip(b"\n") + data[end:])

sources = [
    "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
    "docs/GARAGE_PERFORMANCE_2026_11_01.md",
    "game/ui/car_showroom.gd", "game/ui/garage_reflections.gd",
    "game/tests/bake_garage_cars.gd", "game/tests/bake_garage_architecture.gd",
    "game/tests/support/garage_mesh_lods.gd", "game/tests/bake_garage_mesh_lods.gd",
    "game/tests/profile_garage_render_cost.gd", "game/tests/test_garage_render_optimization.gd",
    "game/tests/probe_garage_kit_control.gd",
    "game/assets/garage/workshop_v1.scn", "game/assets/garage/workshop_v1.provenance.json",
]
sources += [f"game/assets/garage/cars_v1/{car}.scn" for car in ("compact", "kart", "forklift", "electric", "hovercraft")]
before_map = {
    "AGENTS.md": OUT / "before/AGENTS.md",
    "DEVELOPMENT_STATUS.md": OUT / "before/DEVELOPMENT_STATUS.md",
    "docs/PHASE_0_PLAN.md": OUT / "before/PHASE_0_PLAN.md",
}
new = {
    "docs/GARAGE_PERFORMANCE_2026_11_01.md",
    "game/tests/support/garage_mesh_lods.gd", "game/tests/bake_garage_mesh_lods.gd",
    "game/tests/profile_garage_render_cost.gd", "game/tests/test_garage_render_optimization.gd",
    "game/tests/probe_garage_kit_control.gd",
}
for relative in sources:
    if relative in new or relative in before_map:
        continue
    archived = OUT / "before" / relative
    if not archived.exists():
        archived.parent.mkdir(parents=True, exist_ok=True)
        archived.write_bytes(git(ROOT, "show", "HEAD:" + relative))
    before_map[relative] = archived

index_hash = sha(ROOT / ".git/index")
scratch = ROOT / "build" / ("garage-performance-checkpoint-" + uuid.uuid4().hex[:8])
scratch.mkdir()
git(scratch, "init", "-q")
git(scratch, "config", "core.autocrlf", "false")
for relative, before in before_map.items():
    target = scratch / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(before, target)
git(scratch, "add", ".")
for relative in sources:
    target = scratch / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / relative, target)
git(scratch, "add", "-N", *sorted(new))
patch = OUT / "task.patch"
patch.write_bytes(git(scratch, "diff", "--binary", "--full-index", "--no-ext-diff"))
git(scratch, "apply", "--check", "--reverse", str(patch))
git(scratch, "apply", "--reverse", str(patch))
assert all((scratch / relative).read_bytes() == before.read_bytes() for relative, before in before_map.items())
git(scratch, "apply", "--check", str(patch))
git(scratch, "apply", str(patch))
assert all((scratch / relative).read_bytes() == (ROOT / relative).read_bytes() for relative in sources)
assert sha(ROOT / ".git/index") == index_hash

profiles = {renderer: json.loads((OUT / "after" / renderer / "report.json").read_text())
            for renderer in ("gl_compatibility", "mobile")}
images = json.loads((OUT / "image-review.json").read_text())
tests = {}
for name in ("final-optimization-native-gl", "final-optimization-native-mobile", "wash-surfaces", "menu-responsiveness", "kit-transition", "kit-transition-control"):
    raw = (OUT / "logs" / (name + ".log")).read_bytes()
    log = raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig", errors="replace")
    tests[name] = [line for line in log.splitlines() if re.search(r"\d+ checks.*\d+ failures", line)]
report = {
    "requirements": ["GPO01", "GPO02", "GPO03", "GPO04"],
    "date": "2026-11-01", "profiles": profiles, "tests": tests,
    "image_pairs": len(images),
    "max_mean_channel_delta_255": max(row["mean_channel_delta_255"] for row in images),
    "max_pixels_over_8_fraction": max(row["pixels_over_8_fraction"] for row in images),
    "files": {relative: {"after_sha256": sha(ROOT / relative), "after_bytes": (ROOT / relative).stat().st_size,
               **({"before_sha256": sha(before_map[relative]), "before_bytes": before_map[relative].stat().st_size} if relative in before_map else {})}
              for relative in sources},
    "checkpoint": {"patch_sha256": sha(patch), "files": len(sources), "forward_check": True,
                   "reverse_check": True, "exact_content_round_trip": True,
                   "main_index_sha256_unchanged": index_hash, "scratch": str(scratch.relative_to(ROOT))},
    "limitations": ["No physical device query, test or APK/deployment", "Desktop counters do not predict tablet FPS or thermal behavior",
                    "LOD output is perceptual, not pixel-identical; layered Hover and all glazing retain full detail", "Larger assets and resident index memory",
                    "Newly fitted modules and procedural fallback retain original geometry", "Three existing kit-fixture failures reproduce in task-start control",
                    "Owner appearance, device performance and cold-start acceptance remain"],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checkpoint_files": len(sources), "image_pairs": len(images), "tests": tests,
                  "checkpoint_round_trip": True, "main_index_unchanged": True}, indent=2))
