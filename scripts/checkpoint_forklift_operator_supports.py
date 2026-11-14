"""Create and round-trip a small source-only review patch without staging."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
from run_forklift_operator_supports import OUT, ROOT, WORK

files = ["game/vehicle/forklift_model.gd", "game/tests/test_forklift_operator_supports.gd",
         "game/tests/capture_forklift_operator_supports.gd",
         "scripts/run_forklift_operator_supports.py", "scripts/refresh_forklift_operator_supports.py",
         "scripts/refresh_forklift_support_dependencies.py", "scripts/checkpoint_forklift_operator_supports.py"]
files.append("scripts/verify_forklift_operator_supports.py")
files.append("scripts/repair_forklift_operator_supports.py")
scratch = WORK / "checkpoint"
patch = OUT / "source-changes.patch"
changes = []
expected = {}
for name in files:
    original = (OUT / "before/forklift_model.gd").read_bytes() if name == files[0] else b""
    current = (ROOT / name).read_bytes()
    target = scratch / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if original:
        target.write_bytes(original)
    changes.extend(difflib.unified_diff(original.decode("utf-8").splitlines(True),
        current.decode("utf-8").splitlines(True),
        fromfile="a/"+name if original else "/dev/null", tofile="b/"+name))
    expected[name] = (original, current)
patch.write_bytes("".join(changes).encode("utf-8"))
base = ["git", "apply", "--directory="+scratch.relative_to(ROOT).as_posix()]
for args in (["--check"], [], ["--reverse", "--check"], ["--reverse"]):
    subprocess.run(base+args+[str(patch)], cwd=ROOT, check=True)
    if args == []:
        assert all((scratch / name).read_bytes() == current for name, (_, current) in expected.items())
assert (scratch / files[0]).read_bytes() == expected[files[0]][0]
assert all(not (scratch / name).exists() for name in files[1:])
(OUT / "checkpoint-receipt.json").write_text(json.dumps({
    "files":{name:hashlib.sha256(current).hexdigest() for name, (_, current) in expected.items()},
    "forward_exact":True, "reverse_exact":True, "main_index_written":False},indent=2), encoding="utf-8")
print("FORKLIFT_SUPPORT_CHECKPOINT: forward and reverse byte-exact")
