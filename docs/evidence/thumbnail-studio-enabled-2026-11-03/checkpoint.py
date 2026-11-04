"""Round-trip this task's source and PNG changes without touching the main index."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
changed = json.loads((evidence/"snapshot-files.json").read_text())
added = ["game/ui/garage_thumbnail_studio.gd", "game/ui/garage_thumbnail_studio.gd.uid",
         "game/ui/garage_thumbnail_shadow.gdshader", "game/ui/garage_thumbnail_shadow.gdshader.uid",
         "game/tests/test_thumbnail_studio.gd", "game/tests/test_thumbnail_studio.gd.uid",
         "docs/THUMBNAIL_STUDIO_ENABLED_2026_11_03.md",
         *["docs/evidence/thumbnail-studio-enabled-2026-11-03/"+name for name in
           ("run_check.py", "verify.py", "summarize.py", "check_source_identity.ps1", "checkpoint.py")]]
before, after = {}, {}
for name in changed+added:
    new = (root/name).read_bytes()
    old = (evidence/"before"/name).read_bytes() if name in changed else b""
    if name in ("AGENTS.md", "DEVELOPMENT_STATUS.md"):
        begin = b"<!-- THUMBNAIL-STUDIO-ENABLED-20261103 -->"
        end = b"<!-- /THUMBNAIL-STUDIO-ENABLED-20261103 -->"
        assert new.count(begin) == new.count(end) == 1
        start, stop = new.index(begin), new.index(end)+len(end)
        for newline in (b"\r\n\r\n", b"\n\n", b"\r\n", b"\n"):
            if new[stop:stop+len(newline)] == newline:
                stop += len(newline)
                break
        old = new[:start]+new[stop:]
    before[name], after[name] = old, new

owned_root = root/"build/thumbnail-studio-enabled-20261103"
owned = owned_root/("checkpoint-"+str(time.time_ns()))
owned.mkdir(parents=True)
assert owned.resolve().is_relative_to(owned_root.resolve())
environment = os.environ.copy()
# Work outside repository discovery so its PowerShell eol rule cannot rewrite
# LF snapshots while checking byte preservation. No temporary repository/index.
environment.update(GIT_CEILING_DIRECTORIES=str(owned_root.resolve()), GIT_ATTR_NOSYSTEM="1")
for tree, content, files in [("a", before, changed), ("b", after, changed+added), ("roundtrip", before, changed)]:
    for name in files:
        target = owned/tree/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content[name])
diff = subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "core.attributesFile=", "diff", "--no-index", "--binary",
                       "--src-prefix=", "--dst-prefix=", "a", "b"], cwd=owned, env=environment, capture_output=True)
assert diff.returncode == 1, diff.stderr
patch = evidence/"task.patch"
patch.write_bytes(diff.stdout)
commands = []
for arguments in [("--check",), (), ("--reverse", "--check"), ("--reverse",)]:
    command = ["git", "-c", "core.autocrlf=false", "-c", "core.attributesFile=", "apply",
               "--directory=roundtrip", *arguments, str(patch.resolve())]
    result = subprocess.run(command, cwd=owned, env=environment, capture_output=True, text=True)
    commands.append({"command": command, "cwd": str(owned), "ceiling": environment["GIT_CEILING_DIRECTORIES"],
                     "exit_code": result.returncode, "output": result.stdout+result.stderr})
    assert result.returncode == 0, result.stderr
    if not arguments:
        assert all((owned/"roundtrip"/name).read_bytes() == after[name] for name in changed+added)
assert all((owned/"roundtrip"/name).read_bytes() == before[name] for name in changed)
assert all(not (owned/"roundtrip"/name).exists() for name in added)
receipt = {"files": changed+added, "main_index_written": False, "forward_content_exact": True,
           "reverse_content_exact": True, "commands": commands,
           "patch_sha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
           "source_sha256": {name: hashlib.sha256(after[name]).hexdigest() for name in changed+added}}
(evidence/"checkpoint.json").write_text(json.dumps(receipt, indent=2)+"\n")
print("Task-only source/binary patch applies and reverses byte-exactly; main index untouched.")
