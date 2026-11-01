"""Task-start source checkpoint; only an owned temporary repository is mutated."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import uuid

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
existing = [str(path.relative_to(evidence / "before")).replace("\\", "/")
            for path in (evidence / "before").rglob("*") if path.is_file()]
added = [
    "scripts/translations/daily_timer_words.tsv", "docs/DAILY_TIMER_WORDS_2026_11_01.md",
    "docs/evidence/daily-timer-words-2026-11-01/run_native.py",
    "docs/evidence/daily-timer-words-2026-11-01/checkpoint.py",
]
added += [name + ".uid" for name in added if name.endswith(".gd")]
paths = sorted(set(existing + added))
before, after, patches, entries = {}, {}, [], []
for name in paths:
    old = evidence / "before" / name
    new = root / name
    before[name] = old.read_text(encoding="utf-8") if old.exists() else None
    after[name] = new.read_text(encoding="utf-8")
    if before[name] == after[name]:
        continue
    patches.append("diff --git a/" + name + " b/" + name + "\n")
    if not old.exists():
        patches.append("new file mode 100644\n")
    patches.extend(difflib.unified_diff((before[name] or "").splitlines(keepends=True),
        after[name].splitlines(keepends=True), fromfile="a/"+name if old.exists() else "/dev/null",
        tofile="b/"+name))
    entries.append({"path":name,"sha256":hashlib.sha256(new.read_bytes()).hexdigest(),
                    "before_sha256":hashlib.sha256(old.read_bytes()).hexdigest() if old.exists() else None})
patch = evidence / "task.patch"
patch.write_text("".join(patches),encoding="utf-8",newline="\n")
workspace = root / "build" / ("daily-timer-words-checkpoint-"+uuid.uuid4().hex[:10])
workspace.mkdir(parents=True)
assert workspace.resolve().is_relative_to((root / "build").resolve())
def run(*args):
    result = subprocess.run(["git", "-c", "core.autocrlf=false", *args], cwd=workspace,
                            capture_output=True,text=True)
    if result.returncode:
        raise RuntimeError(result.stdout+result.stderr)
run("init", "--quiet")
for name, content in before.items():
    if content is not None:
        file = workspace / name
        file.parent.mkdir(parents=True,exist_ok=True)
        file.write_text(content,encoding="utf-8",newline="\n")
run("apply", "--check", str(patch))
run("apply", str(patch))
assert all((workspace/name).read_text(encoding="utf-8") == content for name, content in after.items())
run("apply", "--reverse", "--check", str(patch))
run("apply", "--reverse", str(patch))
assert all(not (workspace/name).exists() if content is None else
           (workspace/name).read_text(encoding="utf-8") == content for name, content in before.items())
report = {"requirements":["DTF01"],"source_files":entries,
          "checkpoint":{"forward_check":True,"forward_content":True,"reverse_check":True,
                        "reverse_content":True,"comparison":"normalized UTF-8 text","main_index_changed":False},
          "validation":{"presentation_native":{"checks":307,"failures":0},"catalogue_checks":12},
          "limits":["No phone/Android test", "No backend change or deployment", "Reload and owner acceptance remain",
                    "Existing isolated root-certificate-store warning"],
          "screenshots":sorted(str(p.relative_to(evidence)).replace("\\","/") for p in evidence.rglob("*.png"))}
(evidence / "report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(f"{len(entries)} files: forward/reverse application and normalized content checks pass")
