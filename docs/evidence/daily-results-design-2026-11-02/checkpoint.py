"""Verify a scoped task-start patch in a disposable repository, never the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import uuid

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
existing = [str(p.relative_to(out / "before")).replace("\\", "/")
            for p in (out / "before").rglob("*") if p.is_file()]
added = [
    "game/ui/daily_results_standings.gd", "game/ui/daily_results_standings.gd.uid",
    "game/tests/test_daily_results_design.gd", "game/tests/test_daily_results_design.gd.uid",
    "scripts/translations/daily_results_design.tsv", "docs/DAILY_RESULTS_DESIGN_2026_11_02.md",
    "docs/evidence/daily-results-design-2026-11-02/run_native.py",
    "docs/evidence/daily-results-design-2026-11-02/catalogues.py",
    "docs/evidence/daily-results-design-2026-11-02/checkpoint.py",
]
before, after, chunks, entries = {}, {}, [], []
for name in sorted(set(existing + added)):
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
    entries.append({"path": name, "sha256": hashlib.sha256(new.read_bytes()).hexdigest(),
                    "before_sha256": hashlib.sha256(old.read_bytes()).hexdigest() if old.exists() else None})
patch = out / "task.patch"
patch.write_text("".join(chunks), encoding="utf-8", newline="\n")
workspace = root / "build" / ("daily-results-checkpoint-" + uuid.uuid4().hex[:10])
workspace.mkdir()
assert workspace.resolve().is_relative_to((root / "build").resolve())

def run(*args):
    result = subprocess.run(["git", "-c", "core.autocrlf=false", *args], cwd=workspace,
                            capture_output=True, text=True, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)

run("init", "--quiet")
for name, text in before.items():
    if text is not None:
        path = workspace / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")
run("apply", "--check", str(patch))
run("apply", str(patch))
assert all((workspace / name).read_text(encoding="utf-8") == text for name, text in after.items())
run("apply", "--reverse", "--check", str(patch))
run("apply", "--reverse", str(patch))
assert all(not (workspace / name).exists() if text is None else
           (workspace / name).read_text(encoding="utf-8") == text for name, text in before.items())
report = {"requirements": ["DRD01", "DRD02", "DRD03", "DRD04"],
          "files": entries,
          "checkpoint": {"forward_check": True, "forward_content": True,
                         "reverse_check": True, "reverse_content": True,
                         "comparison": "normalized UTF-8 text", "main_index_changed": False},
          "validation": {"native_compatibility": {"checks": 173, "failures": 0},
                         "native_desktop_mobile": {"checks": 173, "failures": 0},
                         "retained_rules_results": {"checks": 115, "failures": 0},
                         "actual_app": {"checks": 17, "failures": 0},
                         "fixed_presentation": {"checks": 438, "failures": 0},
                         "full_standings": {"checks": 38, "failures": 0},
                         "authored_catalogue_checks": 84},
          "screenshots": sorted(str(p.relative_to(out)).replace("\\", "/") for p in out.rglob("*.png")),
          "limits": ["Native captures use explicit synthetic standings through actual UI",
                     "Existing endpoint supplies two actual neighbours plus attempt",
                     "No phone/Android test; owner visual/touch acceptance remains",
                     "No backend/live mutation, deployment, APK, owner-save/process restart",
                     "Existing root-certificate warning; import also reports missing Android build-tools"]}
(out / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(f"DAILY_RESULTS_CHECKPOINT: {len(entries)} files, forward/reverse application and content pass")
