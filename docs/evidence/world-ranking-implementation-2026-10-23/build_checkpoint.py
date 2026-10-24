"""Create a task-only review patch; never stage or commit the shared workspace."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
before = OUT / "before"
shared = {p.relative_to(before).as_posix():p for p in before.rglob("*") if p.is_file()}
for name in ("AGENTS.md","DEVELOPMENT_STATUS.md"):
    shared[name] = OUT / "checkpoint-base" / name
patterns = ["backend/bmt_backend/world_ranking*.py","backend/bmt_backend/world_circuit.py",
    "backend/bmt_backend/migrations/versions/0059_world_ranking.py","backend/tests/test_world_ranking*.py",
    "game/backend/world_ranking_client.gd*","game/ui/world_ranking*.gd*","game/tests/test_world_ranking.gd*",
    "docs/schemas/world-ranking-v1.schema.json","docs/WORLD_RANKING_IMPLEMENTATION_2026_10_23.md"]
new = {p.relative_to(ROOT).as_posix() for pattern in patterns for p in ROOT.glob(pattern) if p.is_file()}
for helper in ("run_native.py","run_native_regressions.py","run_original_control.py","run_postgres.py","build_checkpoint.py","record_evidence.py"):
    new.add((OUT / helper).relative_to(ROOT).as_posix())
patch, manifest = [], []
for name in sorted(set(shared).union(new)):
    current = ROOT / name
    original = shared.get(name)
    old = original.read_bytes() if original else b""
    data = current.read_bytes()
    a,b = old.decode("utf-8").splitlines(keepends=True),data.decode("utf-8").splitlines(keepends=True)
    # Git text patches use LF; byte hashes still record the exact working files.
    a = [line.replace("\r\n","\n") for line in a]
    b = [line.replace("\r\n","\n") for line in b]
    if a == b: continue
    patch.append("diff --git a/"+name+" b/"+name+"\n")
    if original is None: patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(a,b,fromfile="a/"+name if original else "/dev/null",tofile="b/"+name))
    manifest.append({"path":name,"before_sha256":hashlib.sha256(old).hexdigest() if original else None,
        "after_sha256":hashlib.sha256(data).hexdigest(),"bytes":len(data),
        "base":"new" if original is None else "current concurrent docs minus own section" if name in ("AGENTS.md","DEVELOPMENT_STATUS.md")
        else "task additions removed to reconstruct base" if name in ("game/race/weekly_rivalry.gd","game/ui/weekly_rivalry_finale.gd")
        else "captured before editing"})
target = OUT / "checkpoint.patch"
target.write_bytes("".join(patch).encode("utf-8"))
result = subprocess.run(["git","apply","--reverse","--check","--whitespace=nowarn",str(target)],
    cwd=ROOT,capture_output=True,text=True,check=False)
receipt = {"files":manifest,"patch_sha256":hashlib.sha256(target.read_bytes()).hexdigest(),
    "reverse_check_exit_code":result.returncode,"reverse_check_output":result.stdout+result.stderr,
    "scope":"Task-only current-working-tree patch. No index, commit, deployment or unrelated changes."}
(OUT / "checkpoint.json").write_text(json.dumps(receipt,indent=2),encoding="utf-8")
print(json.dumps({"files":len(manifest),"patch_bytes":target.stat().st_size,
    "reverse_check_exit_code":result.returncode,"output":(result.stdout+result.stderr)[-3000:]}))
raise SystemExit(result.returncode)
