"""Create and round-trip a task-only patch without using the workspace index."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = next(path for path in Path(__file__).resolve().parents if (path / 'game/project.godot').exists())
OUT = Path(__file__).resolve().parent
files = ['game/vehicle/' + name for name in [
    'electric_car_model.gd', 'electric_reference_body.gd', 'electric_reference_cabin.gd',
    'electric_reference_details.gd', 'electric_reference_mesh.gd']]
files += ['game/tests/' + name + suffix for name in [
    'review_volt_sport_redesign.gd', 'test_volt_sport_redesign.gd'] for suffix in ['', '.uid']]
files += ['docs/VOLT_SPORT_REDESIGN_2026_10_31.md', 'DEVELOPMENT_STATUS.md']
work = Path(tempfile.mkdtemp(prefix='volt-sport-checkpoint-', dir=ROOT / 'tmp'))
before, after, verify = [work / name for name in ['before', 'after', 'verify']]
for directory in [before, after, verify]: directory.mkdir()

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

for name in files:
    previous = OUT / 'task-base' / name
    if previous.exists():
        target = before / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(previous, target)
    target = after / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / name, target)
    archive = OUT / 'task-final' / name
    archive.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(target, archive)

result = subprocess.run(['git', '-c', 'core.autocrlf=false', 'diff', '--no-index', '--binary', '--src-prefix=a/',
                         '--dst-prefix=b/', 'before', 'after'], cwd=work, capture_output=True)
assert result.returncode == 1, result.stderr.decode(errors='replace')
patch = []
for line in result.stdout.splitlines(keepends=True):
    if line.startswith((b'diff --git ', b'--- ', b'+++ ', b'Binary files ')):
        # A newly added file may use the after path for both diff header sides.
        for prefix in [b'a/before/', b'a/after/']:
            line = line.replace(prefix, b'a/')
        for prefix in [b'b/after/', b'b/before/']:
            line = line.replace(prefix, b'b/')
    patch.append(line)
patch_file = OUT / 'task.patch'
patch_file.write_bytes(b''.join(patch))
shutil.copytree(before, verify, dirs_exist_ok=True)
env = os.environ.copy()
env['GIT_CEILING_DIRECTORIES'] = str(work)
commands = []
for args in [ ['--check'], [], ['--reverse', '--check'], ['--reverse'] ]:
    command = ['git', '-c', 'core.autocrlf=false', 'apply', *args, str(patch_file)]
    applied = subprocess.run(command, cwd=verify, env=env, capture_output=True)
    commands.append({'command': command, 'exit_code': applied.returncode,
                     'stderr': applied.stderr.decode(errors='replace')})
    assert applied.returncode == 0, commands[-1]
    if not args:
        assert all((verify / name).read_bytes() == (after / name).read_bytes() for name in files)
    if args == ['--reverse']:
        for name in files:
            path = verify / name
            assert path.exists() == (before / name).exists()
            if path.exists(): assert path.read_bytes() == (before / name).read_bytes()
proof = {'source_only': True, 'main_index_used': False, 'patch_sha256': digest(patch_file),
         'files': [{'path': name, 'before': digest(before/name) if (before/name).exists() else None,
                    'after': digest(after/name)} for name in files],
         'commands': commands, 'forward_content_exact': True, 'reverse_content_exact': True}
(OUT / 'checkpoint.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
print(json.dumps({'files': len(files), 'patch_bytes': patch_file.stat().st_size,
                  'forward_content_exact': True, 'reverse_content_exact': True}))
