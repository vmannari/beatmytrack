"""Retain actual logs, hashes and a review patch without shared unrelated edits."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
EXISTING = json.loads((HERE / "baseline-paths.json").read_text())
NEW = ["backend/bmt_backend/reward_rank_cache.py",
       "backend/bmt_backend/migrations/versions/0070_reward_cache_revisions.py",
       "backend/tests/test_backend_work_reduction.py", "docs/BACKEND_WORK_REDUCTION_2026_10_26.md"]
LOGS = ["initial", "initial-r2", "focused", "focused-r2", "final-focused", "focused-final",
        "related", "recheck", "native", "native-cost", "benchmark", "baseline-probe", "ruff"]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def log_text(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8")


def without_task(name, text):
    if name == "backend/bmt_backend/runs.py":
        pairs = [
            ("from .storage import prepare_json\n", ""),
            ('    prepared = prepare_json(payload.replay)\n    body = {"ticket_id": payload.ticket_id, "replay_hash": prepared.digest}\n',
             '    body = {"ticket_id": payload.ticket_id, "replay_hash": digest(payload.replay)}\n'),
            ('    replay_hash = request.app.state.blobs.put_json(prepared)\n',
             '    replay_hash = request.app.state.blobs.put_json(payload.replay)\n'),
        ]
        for after, before in pairs:
            assert text.count(after) == 1, (name, after)
            text = text.replace(after, before)
        return text
    if name in ("AGENTS.md", "DEVELOPMENT_STATUS.md"):
        start = text.index("<!-- BACKEND-WORK-REDUCTION-20261026 -->")
        end = text.index("<!-- /BACKEND-WORK-REDUCTION-20261026 -->") + len("<!-- /BACKEND-WORK-REDUCTION-20261026 -->\n\n")
        return text[:start] + text[end:]
    return (HERE / "before" / name).read_text(encoding="utf-8")


logs = {}
for name in LOGS:
    source = ROOT / "build" / ("backend-work-reduction-"+name+".log")
    output = HERE / (name+".log")
    text = log_text(source)
    output.write_text(text, encoding="utf-8", newline="\n")
    logs[name] = {"path":str(output.relative_to(ROOT)).replace("\\", "/"), "sha256":digest(output.read_bytes())}
assert "33 passed" in (HERE / "focused-final.log").read_text()
assert "100 passed" in (HERE / "initial-r2.log").read_text()
assert "2 passed" in (HERE / "native.log").read_text()
assert "1 passed" in (HERE / "native-cost.log").read_text()
assert "7 passed" in (HERE / "recheck.log").read_text()
assert "3 failed, 1 passed" in (HERE / "baseline-probe.log").read_text()
assert "All checks passed" in (HERE / "ruff.log").read_text()

chunks, sources, concurrent = [], {}, {}
for name in EXISTING + ["AGENTS.md", "DEVELOPMENT_STATUS.md"] + NEW:
    path = ROOT / name
    current = path.read_text(encoding="utf-8")
    before = "" if name in NEW else without_task(name, current)
    sources[name] = digest(path.read_bytes())
    if before == current:
        continue
    if name == "backend/bmt_backend/runs.py":
        initial = (HERE / "before" / name).read_text()
        if initial != before:
            concurrent[name] = {"task_start_sha256":digest(initial.encode()),
                                "current_without_task_sha256":digest(before.encode()),
                                "note":"Concurrent histogram changes preserved and excluded from patch"}
    chunks.append(f"diff --git a/{name} b/{name}\n")
    if name in NEW:
        chunks.append("new file mode 100644\n")
    chunks.extend(difflib.unified_diff(before.splitlines(keepends=True), current.splitlines(keepends=True),
        fromfile="/dev/null" if name in NEW else "a/"+name, tofile="b/"+name))
patch = HERE / "checkpoint.patch"
patch.write_text("".join(chunks), encoding="utf-8", newline="\n")
checked = subprocess.run(["git", "apply", "--reverse", "--check", str(patch)],
                         cwd=ROOT, capture_output=True, text=True, check=False)
(HERE / "checkpoint-check.log").write_text(checked.stdout+checked.stderr, encoding="utf-8")
assert checked.returncode == 0, checked.stderr

report = {"requirements":["BWR01","BWR02","BWR03","BWR04","R01","Q01"],
          "sources":sources, "logs":logs, "excluded_concurrent":concurrent,
          "checkpoint":{"path":str(patch.relative_to(ROOT)).replace("\\", "/"),
                        "sha256":digest(patch.read_bytes()), "reverse_git_apply_check":checked.returncode},
          "benchmark":json.loads((HERE / "benchmark.json").read_text()),
          "acceptance":{"focused_passed":33, "native_tests_passed":3,
                        "live_postgres_tested":False, "migration_required":"0070_reward_cache_revisions",
                        "deployed":False,"device_tested":False,"owner_process_restarted":False}}
(HERE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"sources":len(sources), "retained_logs":len(logs), "patch_bytes":patch.stat().st_size,
                  "reverse_git_apply_check":checked.returncode, "excluded_concurrent":list(concurrent)}, indent=2))
