"""Create and round-trip a task-only source patch without touching the shared index."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').is_file())
WORK = ROOT / 'build/garage-selected-2026-11-15'
OUT = Path(__file__).resolve().parent
digest = lambda data: hashlib.sha256(data).hexdigest()
modified = ['game/ui/garage_page.gd', 'AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']
added = ['docs/GARAGE_SELECTED_STYLE_2026_11_15.md']
added += [str((OUT / name).relative_to(ROOT)).replace('\\', '/') for name in
          ['capture_garage_selected_review.gd', 'run.py', 'checkpoint.py']]
before = {name: (WORK / 'before' / name).read_bytes() for name in modified}
after = {name: (ROOT / name).read_bytes() for name in modified + added}
index_before = digest((ROOT / '.git/index').read_bytes())
private = (WORK / 'source-checkpoint').resolve()
assert private.is_relative_to(WORK.resolve()) and not private.exists()
private.mkdir()

def git(*args):
    result = subprocess.run(['git', '-c', 'core.autocrlf=false', '-c',
        'core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol', *args],
        cwd=private, capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors='replace')
    return result.stdout

def write(files):
    for name, data in files.items():
        path = private / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

git('init', '--quiet')
git('config', 'user.name', 'Local task checkpoint')
git('config', 'user.email', 'checkpoint@invalid.local')
write(before)
git('add', '--all')
git('commit', '--quiet', '-m', 'Task-start selection style and surrounding sources')
write(after)
git('add', '--all')
git('diff', '--cached', '--check')
patch = git('diff', '--cached', '--binary', '--full-index', 'HEAD')
(OUT / 'source.patch').write_bytes(patch)
git('apply', '--check', '--reverse', str(OUT / 'source.patch'))
git('apply', '--reverse', '--whitespace=error', str(OUT / 'source.patch'))
for name in after:
    path = private / name
    assert (not path.exists()) if name not in before else path.read_bytes() == before[name], name
git('apply', '--whitespace=error', str(OUT / 'source.patch'))
for name, data in after.items():
    assert (private / name).read_bytes() == data, name
git('commit', '--quiet', '-m', 'GSS01-GSS03 refine Garage selected status')
assert digest((ROOT / '.git/index').read_bytes()) == index_before
receipt = {'files': {name: {'before_sha256': digest(before[name]) if name in before else None,
                          'after_sha256': digest(data)} for name, data in after.items()},
           'forward_byte_exact': True, 'reverse_byte_exact': True, 'whitespace_check': 'passed',
           'shared_index_unchanged_during_checkpoint': True,
           'private_commit': git('rev-parse', 'HEAD').decode().strip(), 'patch_sha256': digest(patch),
           'scope': 'One runtime UI source, task summaries, report and native-review utilities. No generated identity, car source, photo, imported cache or shared staged content.'}
(OUT / 'source-checkpoint.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k: v for k, v in receipt.items() if k != 'files'}))
