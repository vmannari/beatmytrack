"""Prepend task evidence to current trackers; verify a task-only patch without staging."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
summary = '''<!-- VOLT-NIGHT-ROOF-20261106 -->
## Volt pale roof in Night traced to unshaded daytime reflection (2026-11-06)
VNR01-VNR03: Investigation only. Dark panoramic-glass tint uses a fixed unshaded daytime sky; no biome input. Production Game/stock Volt native Compatibility passes13/0 with seven captures. All16780 isolated roof pixels remain exact under Night, day and all lights off; restored frame/track/state exact. Recommend car-owned Night reflection palette with daylight/studio and shared Hovercraft/prepared-asset checks. No runtime fix. [Evidence, commands, limits and task-only checkpoint](LINK). Initial execution-policy/native-access failures retained; standard entry point refreshes generated build identity. No device query/test, APK, owner-save/process change, live/backend request, deployment or main-index write; concurrent work preserved. Corrected implementation and owner/device acceptance remain.
<!-- /VOLT-NIGHT-ROOF-20261106 -->

'''
before = {}
after = {}
for relative in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    path = root / relative
    old = path.read_bytes()
    link = 'VOLT_NIGHT_ROOF_2026_11_06.md' if relative.startswith('docs/') else 'docs/VOLT_NIGHT_ROOF_2026_11_06.md'
    prefix = summary.replace('LINK', link).encode('utf-8')
    if old.startswith(prefix): old = old[len(prefix):]
    assert b'<!-- VOLT-NIGHT-ROOF-20261106 -->' not in old
    new = prefix + old
    before[relative] = old
    after[relative] = new
    path.write_bytes(new)
for relative in ['game/tests/review_volt_night_roof.gd', 'docs/VOLT_NIGHT_ROOF_2026_11_06.md',
                 'docs/evidence/volt-night-roof-2026-11-06/run_review.py',
                 'docs/evidence/volt-night-roof-2026-11-06/checkpoint.py']:
    before[relative] = b''
    after[relative] = (root / relative).read_bytes()
patch = b''
for relative in before:
    patch += b''.join(difflib.diff_bytes(difflib.unified_diff,
        before[relative].splitlines(keepends=True), after[relative].splitlines(keepends=True),
        fromfile=('a/' + relative).encode() if before[relative] else b'/dev/null',
        tofile=('b/' + relative).encode()))
patch_path = evidence / 'task.patch'
patch_path.write_bytes(patch)
with tempfile.TemporaryDirectory(prefix='bmt-volt-night-checkpoint-') as temporary:
    directory = Path(temporary)
    subprocess.run(['git', 'init', '-q', str(directory)], check=True)
    subprocess.run(['git', '-C', str(directory), 'config', 'core.autocrlf', 'false'], check=True)
    for relative, content in before.items():
        if not content: continue
        path = directory / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    commands = []
    for options in [['--check'], [], ['--reverse', '--check'], ['--reverse']]:
        command = ['git', '-C', str(directory), 'apply', *options, str(patch_path)]
        completed = subprocess.run(command, capture_output=True, text=True)
        commands.append({'options': options, 'exit_code': completed.returncode, 'stderr': completed.stderr})
        assert completed.returncode == 0, completed.stderr
        if options == []:
            assert all((directory / path).read_bytes() == content for path, content in after.items())
    assert all((directory / path).read_bytes() == content if content else not (directory / path).exists()
               for path, content in before.items())
receipt = {'files': list(before), 'patch_sha256': hashlib.sha256(patch).hexdigest(),
           'forward_content_exact': True, 'reverse_content_exact': True, 'commands': commands}
(evidence / 'checkpoint.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
print(json.dumps(receipt))
