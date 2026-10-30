from pathlib import Path
import difflib
import hashlib
import json
import subprocess
import tempfile

root = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
out = Path(__file__).resolve().parent
prior = root / 'docs/evidence/garage-ready-pictures-2026-10-28'
receipt = json.loads((prior / 'garage-opt-baseline-outside-20261030-seed/command.json').read_text())
paths = ['game/core/app.gd', 'game/ui/garage_preloader.gd', 'game/ui/garage_preview_cache.gd',
         'game/tests/test_garage_ready_pictures.gd', 'game/tests/test_garage_preview_pipeline.gd']
after = {p: (root / p).read_text(encoding='utf-8') for p in paths}
before = dict(after)
before[paths[0]] = before[paths[0]].replace(
    '(_retained_garage._preview_service.worker != null or not _retained_garage._preview_service.pending_writes.is_empty())',
    '_retained_garage._preview_service.worker != null')
before[paths[1]] = before[paths[1]].replace(
    'picture_service.worker!=null or not picture_service.pending_writes.is_empty()', 'picture_service.worker!=null')
before[paths[2]] = (prior / 'after/game/ui/garage_preview_cache.gd').read_text(encoding='utf-8')
before[paths[3]] = (prior / 'garage-opt-baseline-outside-20261030-seed/test-source.gd').read_text(encoding='utf-8')
before[paths[4]] = ''
for path in paths[:4]:
    assert hashlib.sha256(before[path].encode()).hexdigest() == receipt['before_hashes'][path], path
patch = ''.join(''.join(difflib.unified_diff(before[p].splitlines(keepends=True), after[p].splitlines(keepends=True),
    fromfile='a/'+p if before[p] else '/dev/null', tofile='b/'+p)) for p in paths)
(out / 'task.patch').write_text(patch, encoding='utf-8', newline='\n')
with tempfile.TemporaryDirectory(prefix='bmt-garage-patch-') as directory:
    work = Path(directory)
    for path in paths:
        if before[path]:
            target = work / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(before[path], encoding='utf-8', newline='\n')
    cmd = ['git', 'apply', '--whitespace=error', str(out / 'task.patch')]
    subprocess.run(cmd + ['--check'], cwd=work, check=True)
    subprocess.run(cmd, cwd=work, check=True)
    assert all((work / p).read_text(encoding='utf-8') == after[p] for p in paths)
    subprocess.run(cmd + ['--reverse', '--check'], cwd=work, check=True)
    subprocess.run(cmd + ['--reverse'], cwd=work, check=True)
    assert all((work / p).read_text(encoding='utf-8') == before[p] for p in paths if before[p])
    assert not (work / paths[4]).exists()
print('Scoped patch forward and reverse content checks passed')
