"""Keep this tab's review delta separate from the shared branch and index."""
from pathlib import Path
import difflib
import hashlib
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
STATUS = "2026-10-10 CH01/CH03-CH06/CH15/V03-V05/R01/Q01: owner narrows benchmark-led pass to Race Challenges tab. Scenic inbox cards expose actual competition/time/expiry; separate readable target/own-best/gap panel, four aligned signed-gap standings columns and four compact rows. Ties/sharedlead/no-time/ended/exhausted/creator/guest states honest; original creation/result presenters and service contracts retained. Final graphical integration140/tab63/App99 pass; final desktop/compact captures inspected. Concurrent GrassBirds generated-cache omission corrected locally; Import remained blocked by loaded Windows DLL, no unrelated source/editor changes. No phone check/device/APK/fullValidate/backend/deploy/physics/live writes. Files/commands/evidence/task-only checkpoint/owner and device acceptance: docs/CHALLENGE_TAB.md.\n\n"
FILES = ["game/ui/challenges_page.gd", "game/tests/test_challenge_tab.gd", "game/tests/test_challenge_tab.gd.uid", "docs/CHALLENGE_TAB.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
BASE = EVIDENCE / "checkpoint-base"
BASE.mkdir(exist_ok=True)

def run_git(*arguments, env=None, data=None):
    result = subprocess.run(["git", *arguments], cwd=ROOT, env=env, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return result.stdout.decode().strip()

if "--git" not in sys.argv:
    patch = []
    hashes = {}
    for name in FILES:
        path = ROOT / name
        current = path.read_text(encoding="utf-8-sig")
        if name in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
            if STATUS not in current:
                current = STATUS + current
                path.write_text(current, encoding="utf-8", newline="\n")
            original = current.replace(STATUS, "", 1)
        elif name == "game/ui/challenges_page.gd":
            original = (EVIDENCE / "before/challenges_page.gd").read_text(encoding="utf-8-sig")
        else:
            original = ""
        (BASE / name.replace("/", "__")).write_text(original, encoding="utf-8", newline="\n")
        patch.extend(difflib.unified_diff(original.splitlines(keepends=True), current.splitlines(keepends=True), fromfile="a/"+name if original else "/dev/null", tofile="b/"+name))
        hashes[name] = {"before_lf": hashlib.sha256(original.encode()).hexdigest(), "after_lf": hashlib.sha256(current.encode()).hexdigest()}
    (EVIDENCE / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
    (EVIDENCE / "source-hashes.json").write_text(json.dumps(hashes, indent=2)+"\n", encoding="utf-8")
    print("Prepared six-file task-only patch and status entries.")
else:
    head = run_git("rev-parse", "HEAD")
    index = Path(run_git("rev-parse", "--git-path", "index"))
    if not index.is_absolute(): index = ROOT / index
    index_hash = hashlib.sha256(index.read_bytes()).hexdigest() if index.exists() else None
    env = dict(os.environ, GIT_INDEX_FILE=str(EVIDENCE / "checkpoint.index"))
    run_git("read-tree", head, env=env)
    for name in FILES:
        original = (BASE / name.replace("/", "__")).read_bytes()
        if original:
            blob = run_git("hash-object", "-w", "--stdin", data=original)
            run_git("update-index", "--add", "--cacheinfo", "100644", blob, name, env=env)
        else:
            run_git("update-index", "--force-remove", "--", name, env=env)
    before_tree = run_git("write-tree", env=env)
    before = run_git("commit-tree", before_tree, "-p", head, "-m", "Challenge tab task-start review baseline")
    for name in FILES:
        current = (ROOT / name).read_text(encoding="utf-8-sig").encode()
        blob = run_git("hash-object", "-w", "--stdin", data=current)
        run_git("update-index", "--add", "--cacheinfo", "100644", blob, name, env=env)
    after_tree = run_git("write-tree", env=env)
    after = run_git("commit-tree", after_tree, "-p", before, "-m", "Polish the Race Challenges tab and clarify performance and race states")
    ref = "refs/codex/challenge-tab-2026-10-10"
    run_git("update-ref", ref, after)
    assert run_git("rev-parse", "HEAD") == head, "Shared HEAD moved during checkpoint"
    assert (hashlib.sha256(index.read_bytes()).hexdigest() if index.exists() else None) == index_hash, "Shared index changed during checkpoint"
    (EVIDENCE / "checkpoint.json").write_text(json.dumps({"ref":ref,"before":before,"after":after,"head_preserved":head,"index_sha256_preserved":index_hash,"task_files":FILES}, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"ref":ref,"before":before,"after":after,"head_and_index_preserved":True}))
