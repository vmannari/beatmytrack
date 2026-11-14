"""Verify the two authored sources without touching the owner's Git index."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
FILES = [
    'scripts/prepare_challenger.py',
    'scripts/challenger_reference_geometry.py',
]
sha = lambda value: hashlib.sha256(value).hexdigest()
patch = ''
before = {}
after = {}
for name in FILES:
    baseline = OUT / 'before' / Path(name).name
    before[name] = baseline.read_bytes() if baseline.exists() else None
    after[name] = (ROOT / name).read_bytes()
    patch += ''.join(difflib.unified_diff(
        (before[name] or b'').decode('utf-8').splitlines(True),
        after[name].decode('utf-8').splitlines(True),
        'a/' + name if before[name] is not None else '/dev/null',
        'b/' + name))
patch_path = OUT / 'source-only.patch'
patch_path.write_bytes(patch.encode('utf-8'))
check = ROOT / 'build/challenger-corner-roll-2026-11-13/source-checkpoint'
check.mkdir(parents=True, exist_ok=True)
for name in FILES:
    target = check / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if before[name] is not None:
        target.write_bytes(before[name])
    elif target.exists():
        target.unlink()
subprocess.run(['git', 'init', '--quiet', str(check)], check=True)
subprocess.run(['git', '-C', str(check), 'config', 'core.autocrlf', 'false'], check=True)
subprocess.run(['git', '-C', str(check), 'config', 'core.whitespace',
                'blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol'], check=True)
command = ['git', '-C', str(check), 'apply', '--whitespace=error', str(patch_path)]
subprocess.run(command, check=True)
assert all((check / name).read_bytes() == after[name] for name in FILES)
subprocess.run(command[:4] + ['--reverse'] + command[4:], check=True)
assert all((check / name).read_bytes() == before[name] if before[name] is not None
           else not (check / name).exists() for name in FILES)
(OUT / 'source-checkpoint.json').write_text(json.dumps({
    'files': {name: {'before': sha(before[name]) if before[name] is not None else None,
                     'after': sha(after[name])} for name in FILES},
    'forward_exact': True, 'reverse_exact': True, 'whitespace_clean': True,
    'main_index_written': False,
}, indent=2))
print('Two-source checkpoint applies and reverses byte-exactly; whitespace clean')
