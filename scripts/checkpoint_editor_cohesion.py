"""Reversible editor composition/object-flow checkpoint; never stage the shared index."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / ".tmp/editor-cohesion-20261116"
OUT = ROOT / "docs/evidence/editor-cohesion-2026-11-16"
MARKER = "EDITOR-COHESION-20261116"
digest = lambda data: hashlib.sha256(data).hexdigest()
before = {}
after = {}
for original in (WORK / "before/game").rglob("*.gd"):
    name = original.relative_to(WORK / "before").as_posix()
    data = (ROOT / name).read_bytes()
    if original.read_bytes() == data: continue
    before[name] = original.read_bytes()
    after[name] = data
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "docs/track_editor_ux_plan.md"]:
    after[name] = (ROOT / name).read_bytes()
    pattern = (r"<!-- " + MARKER + r" -->\r?\n.*?<!-- /" + MARKER + r" -->\r?\n(?:\r?\n)?").encode()
    before[name], count = re.subn(pattern,b"",after[name],flags=re.S)
    assert count == 1, name
for name in ["game/editor/editor_layout.gd", "game/tests/test_editor_cohesion_2026_11_16.gd", "docs/EDITOR_COHESION_2026_11_16.md", "scripts/checkpoint_editor_cohesion.py"]:
    after[name] = (ROOT / name).read_bytes()
for name in ["game/editor/editor_layout.gd.uid", "game/tests/test_editor_cohesion_2026_11_16.gd.uid"]:
    if (ROOT / name).exists(): after[name] = (ROOT / name).read_bytes()
private = (WORK / "source-checkpoint").resolve()
assert private.is_relative_to(WORK.resolve()) and not private.exists()
private.mkdir(parents=True)
index = digest((ROOT / ".git/index").read_bytes())

def git(*args):
    result = subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol", *args],cwd=private,capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    return result.stdout

def write(files):
    for name, data in files.items():
        path = private / name
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(data)

git("init","--quiet")
git("config","user.name","Local source checkpoint")
git("config","user.email","checkpoint@invalid.local")
write(before); git("add","--all"); git("commit","--quiet","-m","Editor before owner-requested composition and object-flow revision")
write(after); git("add","--all")
patch = git("diff","--cached","--binary","--full-index","HEAD")
(OUT / "source.patch").write_bytes(patch)
git("apply","--check","--reverse",str(OUT / "source.patch"))
git("apply","--reverse","--whitespace=error",str(OUT / "source.patch"))
for name in after:
    path = private / name
    assert path.read_bytes() == before[name] if name in before else not path.exists(), name
git("apply","--whitespace=error",str(OUT / "source.patch"))
for name, data in after.items(): assert (private / name).read_bytes() == data,name
git("diff","--cached","--check")
git("commit","--quiet","-m","Cohesive editor workspace and direct object placement/reselection")
assert digest((ROOT / ".git/index").read_bytes()) == index
receipt = {"files":{name:{"before_sha256":digest(before[name]) if name in before else None,"sha256":digest(data)} for name,data in sorted(after.items())},"forward_byte_exact":True,"reverse_byte_exact":True,"shared_index_unchanged_during_checkpoint":True,"private_commit":git("rev-parse","HEAD").decode().strip(),"patch_sha256":digest(patch),"scope":"Only this follow-up's editor composition, transient stamp state, object interaction, matching regression contracts and marked documentation. Preceding source checkpoint and unrelated/concurrent work preserved."}
(OUT / "source-checkpoint.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
print(json.dumps({key:value for key,value in receipt.items() if key != "files"},indent=2))
