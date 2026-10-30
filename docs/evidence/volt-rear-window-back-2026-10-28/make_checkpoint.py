"""Make and round-trip a task-only patch without touching the shared Git index."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
baseline = json.loads((OUT/'hashes-before-derivatives.json').read_text())
protected = [p for p in baseline if '/electric_coachwork_v16/' in p or p.startswith('game/resources/cars/')]
concurrent_changes = [p for p in protected if sha(ROOT/p) != baseline[p]]
assert all(p.startswith('game/resources/cars/') and not p.endswith('/electric.tres') for p in concurrent_changes), concurrent_changes
paths = {p for p in baseline if p.startswith('game/assets/') and p not in protected and sha(ROOT/p) != baseline[p]}
paths.add('game/vehicle/electric_coachwork.gd')
paths.add('game/tests/audit_volt_rear_window.gd')
if (ROOT/'game/tests/audit_volt_rear_window.gd.uid').exists():
    paths.add('game/tests/audit_volt_rear_window.gd.uid')
paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'game/assets/vehicles/electric_coachwork_v17').iterdir() if p.is_file())
work = ROOT/'tmp'/('volt-window-checkpoint-'+str(time.time_ns()))
before, after, applied = work/'before', work/'after', work/'applied'
for relative in sorted(paths):
    source = OUT/'before'/relative if relative == 'game/vehicle/electric_coachwork.gd' else OUT/'task-base'/relative
    if source.exists():
        target = before/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    target = after/relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT/relative, target)
subprocess.run(['git', 'init', '--quiet', str(work)], check=True)
subprocess.run(['git', '-C', str(work), 'config', 'core.autocrlf', 'false'], check=True)
result = subprocess.run(['git', 'diff', '--no-index', '--binary', '--', 'before', 'after'], cwd=work, capture_output=True)
assert result.returncode == 1, result.stderr.decode(errors='replace')
patch = result.stdout.replace(b'a/before/', b'a/').replace(b'b/after/', b'b/')
# New files have their right-side path on both sides of the diff header.
patch = patch.replace(b'a/after/', b'a/').replace(b'b/before/', b'b/')
patch_path = OUT/'task.patch'
patch_path.write_bytes(patch)
shutil.copytree(before, applied)
subprocess.run(['git', 'init', '--quiet', str(applied)], check=True)
subprocess.run(['git', '-C', str(applied), 'config', 'core.autocrlf', 'false'], check=True)
commands = []
for arguments in [ ['--check'], [], ['--reverse', '--check'], ['--reverse'] ]:
    command = ['git', 'apply', *arguments, str(patch_path)]
    result = subprocess.run(command, cwd=applied, capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors='replace')
    commands.append(command)
    if arguments == []:
        assert all((applied/p).exists() and sha(applied/p) == sha(after/p) for p in paths)
assert all((applied/p).exists() == (before/p).exists() for p in paths)
assert all(sha(applied/p) == sha(before/p) for p in paths if (before/p).exists())
report = dict(files=len(paths), patch_sha256=sha(patch_path), patch_bytes=patch_path.stat().st_size,
              forward_exact=True, reverse_exact=True, protected_files_exact=len(protected)-len(concurrent_changes),
              concurrent_configuration_changes_preserved=concurrent_changes,
              main_index_untouched=True, commands=commands,
              hashes={p: sha(ROOT/p) for p in sorted(paths)})
(OUT/'checkpoint.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ('hashes', 'commands')}))
