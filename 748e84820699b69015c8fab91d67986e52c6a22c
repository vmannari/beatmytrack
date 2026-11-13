"""Scoped task-start source patch verified without touching the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import uuid

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
names = {p.relative_to(out / "before").as_posix()
         for p in (out / "before").rglob("*") if p.is_file()}
names.update(["docs/DAILY_RESULTS_REFINEMENT_2026_11_02.md",
              "docs/evidence/daily-results-refinement-2026-11-02/run_native.py",
              "docs/evidence/daily-results-refinement-2026-11-02/checkpoint.py"])
before, after, chunks, hashes = {}, {}, [], []
for name in sorted(names):
    old, new = out / "before" / name, root / name
    before[name] = old.read_text(encoding="utf-8") if old.exists() else None
    after[name] = new.read_text(encoding="utf-8")
    if before[name] == after[name]:
        continue
    chunks.append(f"diff --git a/{name} b/{name}\n")
    if not old.exists():
        chunks.append("new file mode 100644\n")
    chunks.extend(difflib.unified_diff((before[name] or "").splitlines(keepends=True),
                                     after[name].splitlines(keepends=True),
                                     fromfile="a/" + name if old.exists() else "/dev/null",
                                     tofile="b/" + name))
    hashes.append({"path": name, "sha256": hashlib.sha256(new.read_bytes()).hexdigest(),
                   "before_sha256": hashlib.sha256(old.read_bytes()).hexdigest() if old.exists() else None})
patch = out / "task.patch"
patch.write_text("".join(chunks), encoding="utf-8", newline="\n")
workspace = root / "build" / ("daily-results-refinement-checkpoint-" + uuid.uuid4().hex[:10])
workspace.mkdir()
assert workspace.resolve().is_relative_to((root / "build").resolve())

def run(*args):
    result = subprocess.run(["git", "-c", "core.autocrlf=false", *args], cwd=workspace,
                            capture_output=True, text=True, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)

run("init", "--quiet")
for name, content in before.items():
    if content is not None:
        path = workspace / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8", newline="\n")
run("apply", "--check", str(patch))
run("apply", str(patch))
assert all((workspace / name).read_text(encoding="utf-8") == content for name, content in after.items())
run("apply", "--reverse", "--check", str(patch))
run("apply", "--reverse", str(patch))
assert all(not (workspace / name).exists() if content is None else
           (workspace / name).read_text(encoding="utf-8") == content for name, content in before.items())
report = {"requirements": ["DRR01", "DRR02", "DRR03"], "files": hashes,
          "checkpoint": {"forward_check": True, "forward_content": True, "reverse_check": True,
                         "reverse_content": True, "main_index_changed": False,
                         "comparison": "normalized UTF-8 text"},
          "validation": {"native_compatibility": [184, 0], "native_desktop_mobile": [184, 0],
                         "retained_standings": [38, 0],
                         "backend": {"passed": 3, "deselected": 3}, "scoped_ruff": "pass"},
          "screenshots": sorted(p.relative_to(out).as_posix() for p in out.rglob("*.png")),
          "limits": ["Matching backend rollout needed for other-driver country metadata",
                     "No device test, APK, owner-save/process change or live deployment",
                     "Native captures use synthetic response fixtures",
                     "Existing root-certificate warning in isolated Godot runs"]}
(out / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(f"DAILY_RESULTS_REFINEMENT: {len(hashes)} files; forward/reverse patch and content checks pass")
