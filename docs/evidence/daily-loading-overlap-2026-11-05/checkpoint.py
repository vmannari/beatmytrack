"""Round-trip only this task's changes in an owned tree; never stage main Git."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
changed = ['game/core/features/race.gd', 'AGENTS.md', 'DEVELOPMENT_STATUS.md']
added = ['game/race/daily_start_preparation.gd', 'game/tests/test_daily_loading_overlap.gd',
         'game/tests/test_daily_loading_worker.gd', 'docs/DAILY_LOADING_OVERLAP_2026_11_05.md']
added += ['docs/evidence/daily-loading-overlap-2026-11-05/'+name for name in
          ('run_check.py', 'run_final_checks.py', 'summarize.py', 'checkpoint.py', 'summary.json',
           'before/game/core/features/race.gd')]
marker = '<!-- DAILY-LOADING-OVERLAP-20261105 -->'
end_marker = '<!-- /DAILY-LOADING-OVERLAP-20261105 -->'
before, after, parts = {}, {}, []
for path in changed+added:
    new = (root/path).read_bytes().replace(b'\r\n', b'\n')
    old = b''
    if path == changed[0]:
        old = (evidence/'before'/path).read_bytes().replace(b'\r\n', b'\n')
    elif path in changed:
        content = new.decode('utf-8')
        assert content.count(marker) == content.count(end_marker) == 1
        start = content.index(marker)
        end = content.index(end_marker)+len(end_marker)
        if content[end:end+2] == '\n\n': end += 2
        elif content[end:end+1] == '\n': end += 1
        old = (content[:start]+content[end:]).encode('utf-8')
    before[path], after[path] = old, new
    parts.append(f'diff --git a/{path} b/{path}\n')
    if path in added: parts.append('new file mode 100644\n')
    parts.extend(difflib.unified_diff(old.decode().splitlines(keepends=True),new.decode().splitlines(keepends=True),
                 fromfile='a/'+path if path in changed else '/dev/null',tofile='b/'+path))
patch = evidence/'task.patch'
patch.write_bytes(''.join(parts).encode('utf-8'))
owned = root/'build/daily-loading-overlap-20261105'/('checkpoint-'+str(time.time_ns()))
owned.mkdir(parents=True)
assert owned.resolve().is_relative_to((root/'build/daily-loading-overlap-20261105').resolve())
for path in changed:
    target = owned/path
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(before[path])
commands = []
for arguments in (('--check',), (), ('--reverse','--check'), ('--reverse',)):
    command = ['git','apply','--directory='+owned.relative_to(root).as_posix(),*arguments,str(patch)]
    result = subprocess.run(command,cwd=root,capture_output=True,text=True)
    commands.append(dict(command=command,exit_code=result.returncode,output=result.stdout+result.stderr))
    assert result.returncode == 0, result.stderr
    if not arguments:
        assert all((owned/path).read_bytes().replace(b'\r\n',b'\n') == after[path] for path in changed+added)
assert all((owned/path).read_bytes().replace(b'\r\n',b'\n') == before[path] for path in changed)
assert all(not (owned/path).exists() for path in added)
report = dict(files=changed+added,forward_content_exact=True,reverse_content_exact=True,main_index_written=False,
              patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),commands=commands,
              source_sha256={path:hashlib.sha256(after[path]).hexdigest() for path in changed+added})
(evidence/'checkpoint.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('Task-only patch forward/reverse/content checks pass; main index unchanged.')
