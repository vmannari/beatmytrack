"""Check a task-only review patch in an owned directory; never touch main index."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
changed = ['AGENTS.md','DEVELOPMENT_STATUS.md']
added = ['game/tests/'+name for name in (
    'review_loading_2026_11_04.gd','review_loading_phases_2026_11_04.gd',
    'review_loading_assets_2026_11_04.gd','review_boot_2026_11_04.gd')]
added += ['docs/LOADING_REVIEW_2026_11_04.md']
added += ['docs/evidence/loading-review-2026-11-04/'+name for name in ('run_review.py','summarize.py','checkpoint.py')]
marker = '<!-- LOADING-REVIEW-20261104 -->'
end_marker = '<!-- /LOADING-REVIEW-20261104 -->'
before, after, parts = {}, {}, []
for path in changed+added:
    new = (root/path).read_bytes().replace(b'\r\n',b'\n')
    old = b''
    if path in changed:
        # Synthesize the task base by removing only our unique marker block.
        # Concurrent tracker updates therefore appear identically on both sides.
        text = new.decode('utf-8')
        assert text.count(marker)==1 and text.count(end_marker)==1
        start = text.index(marker)
        end = text.index(end_marker)+len(end_marker)
        if text[end:end+2]=='\n\n': end += 2
        elif text[end:end+1]=='\n': end += 1
        old = (text[:start]+text[end:]).encode('utf-8')
    before[path], after[path] = old, new
    parts.append(f'diff --git a/{path} b/{path}\n')
    if path in added: parts.append('new file mode 100644\n')
    parts.extend(difflib.unified_diff(old.decode().splitlines(keepends=True),new.decode().splitlines(keepends=True),
        fromfile='a/'+path if path in changed else '/dev/null',tofile='b/'+path))
patch = evidence/'task.patch'
patch.write_bytes(''.join(parts).encode())
owned = root/'build/loading-review-20261104'/('checkpoint-'+str(time.time_ns()))
owned.mkdir(parents=True)
assert owned.resolve().is_relative_to((root/'build/loading-review-20261104').resolve())
for path in changed:
    target = owned/path
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(before[path])
commands = []
for arguments in (('--check',),(),('--reverse','--check'),('--reverse',)):
    command = ['git','apply','--directory='+owned.relative_to(root).as_posix(),*arguments,str(patch)]
    result = subprocess.run(command,cwd=root,capture_output=True,text=True)
    commands.append(dict(command=command,exit_code=result.returncode,output=result.stdout+result.stderr))
    assert result.returncode==0,result.stderr
    if arguments==():
        assert all((owned/path).read_bytes().replace(b'\r\n',b'\n')==after[path] for path in changed+added)
assert all((owned/path).read_bytes().replace(b'\r\n',b'\n')==before[path] for path in changed)
assert all(not (owned/path).exists() for path in added)
report = dict(files=changed+added,forward_content_exact=True,reverse_content_exact=True,main_index_written=False,
    patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),commands=commands,
    source_sha256={path:hashlib.sha256(after[path]).hexdigest() for path in changed+added})
(evidence/'checkpoint.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('Task-only patch forward/reverse/content checks pass; main index unchanged.')
