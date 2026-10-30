"""Freeze task-only sources, commands and binary proof without touching the main index."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / 'godot-version.txt').exists())
FILES = [
    'AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/GARAGE_REFLECTIONS_RESTORED_2026_10_27.md',
    'game/ui/garage_first_draw.gd', 'game/ui/garage_opening_showroom.gd',
    'game/tests/test_garage_cold_opening.gd', 'game/tests/test_garage_opening_tools.gd',
    'game/tests/test_garage_reflections.gd', 'game/tests/test_garage_opening_reflections.gd',
]
for name in ['run_checks.py', 'probe_app_baseline.gd', 'finalize.py',
             'baseline-native/first-live.png', 'fixed-native/first-live.png',
             'app-opening-native/live-studio.png', 'app-opening-mobile/live-studio.png']:
    FILES.append((HERE / name).relative_to(ROOT).as_posix())
uid = ROOT / 'game/tests/test_garage_opening_reflections.gd.uid'
if uid.exists():
    FILES.append(uid.relative_to(ROOT).as_posix())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

before = HERE / 'checkpoint-before'
after = HERE / 'checkpoint-after'
for relative in FILES:
    source = ROOT / relative
    dest = after / relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, dest)
    original = HERE / 'before' / relative
    if original.exists():
        dest = before / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, dest)

# Two existing summary files mix LF and CRLF. Git's automatic CRLF handling
# rewrites their unchanged lines unless these two are carried as exact binary
# deltas. Runtime/test sources remain readable text in the same checkpoint.
diff_root = ROOT / 'build' / ('garage-reflections-restored-diff-' + str(time.time_ns()))
diff_root.mkdir(parents=True)
shutil.copytree(before, diff_root / 'before')
shutil.copytree(after, diff_root / 'after')
subprocess.run(['git', 'init', '--quiet'], cwd=diff_root, check=True)
(diff_root / '.git/info/attributes').write_text('* -text\n**/AGENTS.md -diff\n**/DEVELOPMENT_STATUS.md -diff\n')
diff_cmd = ['git', 'diff', '--no-index', '--no-ext-diff', '--no-textconv', '--binary',
            '--', 'before', 'after']
diff = subprocess.run(diff_cmd, cwd=diff_root, capture_output=True)
assert diff.returncode == 1, diff.stderr.decode(errors='replace')
patch = diff.stdout
for prefix in (b'before/', b'after/'):
    patch = patch.replace(b'a/' + prefix, b'a/').replace(b'b/' + prefix, b'b/')
patch_path = HERE / 'checkpoint.patch'
patch_path.write_bytes(patch)

validation = ROOT / 'build' / ('garage-reflections-restored-checkpoint-' + str(time.time_ns()))
validation.mkdir(parents=True)
shutil.copytree(before, validation, dirs_exist_ok=True)
commands = []
for cmd in [['git', 'init', '--quiet'], ['git', 'apply', '--check', str(patch_path)],
            ['git', 'apply', str(patch_path)], ['git', 'apply', '--check', '--reverse', str(patch_path)]]:
    result = subprocess.run(cmd, cwd=validation, capture_output=True, text=True)
    commands.append(dict(command=cmd, cwd=str(validation), exit_code=result.returncode,
                         stdout=result.stdout, stderr=result.stderr))
    assert result.returncode == 0, commands[-1]
    if cmd[1] == 'init':
        (validation / '.git/info/attributes').write_text('* -text\n')
for relative in FILES:
    assert (validation / relative).read_bytes() == (after / relative).read_bytes(), relative

runs = {p.parent.name: json.loads(p.read_text(encoding='utf-8'))
        for p in sorted(HERE.glob('*/command.json'))}
report = dict(
    requirements=['GRR01', 'GRR02', 'GRR03', 'R01', 'Q01'],
    engine=(ROOT / 'godot-version.txt').read_text().strip(),
    runtime_scope=['game/ui/garage_first_draw.gd', 'game/ui/garage_opening_showroom.gd'],
    checkpoint_files=FILES,
    source_hashes={relative: {'before': digest(before / relative) if (before / relative).exists() else None,
                              'after': digest(after / relative)} for relative in FILES},
    unchanged_facade_hash=digest(ROOT / 'game/ui/garage_opening_facade.gd'),
    unchanged_facade_matches_task_start=(ROOT / 'game/ui/garage_opening_facade.gd').read_bytes() ==
                                       (HERE / 'before/game/ui/garage_opening_facade.gd').read_bytes(),
    runs=runs,
    native_first_live_equals_settled_png=(HERE / 'fixed-native/first-live.png').read_bytes() ==
                                        (HERE / 'fixed-native/reflections-on.png').read_bytes(),
    checkpoint=dict(path=str(patch_path.relative_to(ROOT)), sha256=digest(patch_path),
                    bytes=patch_path.stat().st_size, commands=commands,
                    exact_applied_files=len(FILES), main_index_touched=False),
    limitations=['Initial checkpoint validation exposed existing mixed line endings in the two summary files; '
                 'their exact binary deltas preserve those bytes. The first attempted patch is retained.',
                 'Fresh desktop original live readiness is about 9-27 seconds; picture remains until ready.',
                 'Compatibility cached standalone live readiness is 2.63 seconds, not a phone measurement.',
                 'Cold driver compilation can stall input; no hitch-free guarantee.',
                 'Initial dummy-renderer RID errors did not recur in task-start in-memory control or fixed recheck.',
                 'Certificate-store sandbox error recorded separately for every engine run.',
                 'Reload/rebuild and owner/device appearance/latency acceptance remain.',
                 'No device check/test, APK, real authentication/purchase, owner-save/live mutation, deployment, '
                 'main-index staging/commit/merge or owner-process restart.'],
)
report['artifact_hashes'] = {p.relative_to(HERE).as_posix(): digest(p)
                             for p in sorted(HERE.rglob('*')) if p.is_file()
                             and p != HERE / 'report.json'
                             and not any(part.startswith('checkpoint-') for part in p.relative_to(HERE).parts)}
(HERE / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(dict(runtime_scope=report['runtime_scope'], files=len(FILES),
                     checkpoint=report['checkpoint'],
                     run_exit_codes={label: run['exit_code'] for label, run in runs.items()}), indent=2))
