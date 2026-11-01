"""Create and round-trip a task-only patch without writing the main Git index."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
existing = {
    'game/track/road_surface_height.gd': 'road_surface_height.gd',
    'game/editor/editor_memory.gd': 'editor_memory.gd',
}
added = [
    'game/track/road_support_cache.gd',
    'game/tests/test_loading_road_support.gd',
    'game/tests/profile_loading_support.gd',
    'game/tests/fixtures/loading_road_support_before.gd.txt',
    'docs/LOADING_OPTIMISATION_2026_10_31.md',
]
verification = root / 'build/loading-optimisation-20261031/patch-verification'
assert verification.resolve().is_relative_to((root / 'build').resolve())
verification.mkdir(parents=True, exist_ok=True)
patch = []
after = {}
for name in list(existing) + added:
    prior = (evidence / 'before' / existing[name]).read_text(encoding='utf-8') if name in existing else ''
    current = (root / name).read_text(encoding='utf-8')
    destination = verification / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    if name in existing:
        destination.write_text(prior, encoding='utf-8', newline='\n')
    else:
        assert not destination.exists(), f'Use a fresh verification path: {destination}'
    patch.extend(difflib.unified_diff(prior.splitlines(True), current.splitlines(True),
                                    fromfile='a/'+name if name in existing else '/dev/null',
                                    tofile='b/'+name))
    after[name] = current
    snapshot = evidence / 'after' / name
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_bytes((root / name).read_bytes())
patch_path = evidence / 'task.patch'
patch_path.write_text(''.join(patch), encoding='utf-8', newline='\n')
directory = verification.relative_to(root).as_posix()
commands = []
for flags in [['--check'], [], ['--reverse', '--check'], ['--reverse']]:
    command = ['git', 'apply', '--whitespace=error', '--directory='+directory, *flags,
               str(patch_path.relative_to(root))]
    result = subprocess.run(command, cwd=root, text=True, capture_output=True)
    commands.append({'command': command, 'code': result.returncode, 'output': result.stdout+result.stderr})
    assert result.returncode == 0, commands[-1]
    if flags == []:
        for name, current in after.items():
            assert (verification / name).read_text(encoding='utf-8') == current
for name, saved in existing.items():
    assert (verification / name).read_text(encoding='utf-8') == (evidence / 'before' / saved).read_text(encoding='utf-8')
for name in added:
    assert not (verification / name).exists()
record = {'commands': commands, 'round_trip_exact': True,
          'source_sha256': {name: hashlib.sha256((root/name).read_bytes()).hexdigest() for name in after}}
(evidence / 'checkpoint.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps(record, indent=2))
