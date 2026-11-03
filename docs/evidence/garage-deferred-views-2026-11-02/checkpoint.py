"""Task-only source patch, round-tripped in an owned directory; no index writes."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
changed = ["game/core/app.gd", "game/ui/garage_page.gd", "game/ui/garage_preloader.gd",
           "game/ui/garage_preview_cache.gd", "game/ui/garage_cached_thumbnail.gd",
           "game/ui/garage_opening_showroom.gd", "game/tests/test_garage_preload.gd",
           "game/tests/test_garage_entry_carousel.gd", "game/tests/test_garage_live_entry.gd",
           "game/tests/test_garage_opening_reflections.gd", "game/tests/test_garage_opening_tools.gd",
           "AGENTS.md", "DEVELOPMENT_STATUS.md"]
added = ["game/ui/garage_loading_car.gd", "game/ui/garage_loading_car.gdshader",
         "game/tests/test_garage_deferred_views.gd", "docs/GARAGE_DEFERRED_VIEWS_2026_11_02.md",
         *["docs/evidence/garage-deferred-views-2026-11-02/" + name for name in
           ("run_check.py", "summarize.py", "checkpoint.py")]]

def normalized(path):
    return path.read_bytes().replace(b"\r\n", b"\n")

parts, before, after = [], {}, {}
for path in changed + added:
    new = normalized(root / path)
    old = normalized(evidence / "before" / path) if path in changed else b""
    if path in ("AGENTS.md", "DEVELOPMENT_STATUS.md"):
        # Other tasks may have added notes since this task began. Remove only
        # our exact block from the current document to form its patch base.
        begin = b"<!-- GARAGE-DEFERRED-VIEWS-20261102 -->"
        end = b"<!-- /GARAGE-DEFERRED-VIEWS-20261102 -->"
        assert new.count(begin) == new.count(end) == 1
        start, stop = new.index(begin), new.index(end)+len(end)
        if new[stop:stop+2] == b"\n\n": stop += 2
        elif new[stop:stop+1] == b"\n": stop += 1
        old = new[:start]+new[stop:]
    before[path], after[path] = old, new
    parts.append("diff --git a/"+path+" b/"+path+"\n")
    if path in added: parts.append("new file mode 100644\n")
    parts.extend(difflib.unified_diff(old.decode().splitlines(keepends=True), new.decode().splitlines(keepends=True),
                                    fromfile="a/"+path if path in changed else "/dev/null", tofile="b/"+path))
patch = evidence / "task.patch"
patch.write_bytes("".join(parts).encode())
owned = root / "build/garage-deferred-views-20261102" / ("checkpoint-"+str(time.time_ns()))
owned.mkdir(parents=True)
assert owned.resolve().is_relative_to((root / "build/garage-deferred-views-20261102").resolve())
for path in changed:
    target = owned / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(before[path])
commands = []
for arguments in (("--check",), (), ("--reverse", "--check"), ("--reverse",)):
    command = ["git", "apply", "--directory="+owned.relative_to(root).as_posix(), *arguments, str(patch)]
    result = subprocess.run(command, cwd=root, capture_output=True, text=True)
    commands.append(dict(command=command, exit_code=result.returncode, output=result.stdout+result.stderr))
    assert result.returncode == 0, result.stderr
    if arguments == ():
        assert all(normalized(owned / path) == after[path] for path in changed+added)
assert all(normalized(owned / path) == before[path] for path in changed)
assert all(not (owned / path).exists() for path in added)
receipt = dict(files=changed+added, forward_content_exact=True, reverse_content_exact=True, main_index_written=False,
               patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),
               source_sha256={path: hashlib.sha256(after[path]).hexdigest() for path in changed+added}, commands=commands)
(evidence / "checkpoint.json").write_text(json.dumps(receipt, indent=2)+"\n")
print("Task-only patch: forward/reverse/content checks pass; main index not written.")
