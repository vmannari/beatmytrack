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
    "game/persistence/daily_progress.gd", "game/ui/daily_medal.gd", "game/ui/daily_week.gd",
    "game/ui/daily_result_card.gd", "game/tests/test_daily_medal_page.gd",
    "backend/bmt_backend/daily_lap_standings.py", "backend/tests/test_daily_lap_standings.py",
    "scripts/translations/daily_medal_page.tsv", "docs/DAILY_MEDAL_PAGE_2026_10_31.md",
    "docs/evidence/daily-medal-page-2026-10-31/run_native.py",
    "docs/evidence/daily-medal-page-2026-10-31/checkpoint.py",
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
workspace = root / "build" / ("daily-medal-page-checkpoint-"+uuid.uuid4().hex[:10])
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
report = {"requirements":["DMP01","DMP02","DMP03","DMP04","DMP05","R01"],"source_files":entries,
          "checkpoint":{"forward_check":True,"forward_content":True,"reverse_check":True,
                        "reverse_content":True,"comparison":"normalized UTF-8 text","main_index_changed":False},
          "validation":{"backend_final_focused":{"passed":5,"deselected":4},
                        "backend_broader_regression":{"passed":20,"deselected":19},
                        "medal_page_native":{"checks":88,"failures":0},
                        "daily_page_native":{"checks":77,"failures":0},
                        "standings_headless":{"checks":35,"failures":0},
                        "app_headless":{"checks":13,"failures":0},
                        "rules_headless":{"checks":101,"failures":0},
                        "catalogue_checks":312,"ruff":"pass"},
          "limits":["Daily medals/results remain local cosmetic progress; no survival score or cloud sync",
                    "New lap standings require matching backend/client rollout", "No phone/Android test",
                    "Only desktop Compatibility captured; no device performance claim",
                    "Isolated native runs emit the existing root certificate-store warning"],
          "screenshots":sorted(str(p.relative_to(evidence)).replace("\\","/") for p in evidence.rglob("*.png"))}
(evidence / "report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(f"{len(entries)} files: forward/reverse application and normalized content checks pass")
