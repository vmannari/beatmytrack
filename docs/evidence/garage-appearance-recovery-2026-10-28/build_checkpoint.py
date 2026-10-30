import difflib
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
OUT = Path(__file__).resolve().parent
runtime = 'game/vehicle/vehicle_customisation.gd'
added = ['game/tests/test_garage_appearance_recovery.gd',
         'game/tests/test_garage_appearance_recovery.gd.uid']
before = (OUT / 'before/vehicle_customisation.gd.txt').read_text(encoding='utf-8')
patch = ''.join(difflib.unified_diff(before.splitlines(True),
                (ROOT / runtime).read_text(encoding='utf-8').splitlines(True),
                fromfile='a/' + runtime, tofile='b/' + runtime))
for path in added:
    patch += ''.join(difflib.unified_diff([], (ROOT / path).read_text(encoding='utf-8').splitlines(True),
                     fromfile='/dev/null', tofile='b/' + path))
patch_path = OUT / 'source.patch'
patch_path.write_text(patch, encoding='utf-8', newline='\n')
scratch = ROOT / 'tmp/garage-appearance-recovery-checkpoint'
target = scratch / runtime
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(before, encoding='utf-8', newline='\n')

def git(*arguments):
    result = subprocess.run(['git', 'apply', *arguments, str(patch_path)], cwd=ROOT,
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return {'arguments': list(arguments), 'exit_code': result.returncode,
            'stderr': result.stderr}

prefix = '--directory=' + scratch.relative_to(ROOT).as_posix()
checks = [git('--check', '--reverse'), git('--check', '--whitespace=error', prefix)]
checks.append(git(prefix))
round_trip = {p: (scratch / p).read_bytes() == (ROOT / p).read_bytes()
              for p in [runtime] + added}
assert all(round_trip.values()), round_trip
checks.append(git('--reverse', prefix))
assert target.read_text(encoding='utf-8') == before
assert all(not (scratch / p).exists() for p in added)
commands = {p.parent.name: json.loads(p.read_text(encoding='utf-8'))
            for p in OUT.glob('*/command.json')}
report = {
    'requirements': ['GARC01', 'GARC02', 'GARC03'],
    'observed_failure': json.loads((OUT / 'owner-log-observation.json').read_text(encoding='utf-8')),
    'passing_checks': {'recovery_headless': 70, 'records': 54, 'appearance_sync': 54,
                       'recovery_native_compatibility': 83},
    'passing_check_total': 261,
    'commands': commands,
    'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
                      for p in [runtime] + added},
    'source_patch_sha256': hashlib.sha256(patch_path.read_bytes()).hexdigest(),
    'checkpoint_checks': checks,
    'checkpoint_round_trip_exact': round_trip,
    'native_screenshots': [p.relative_to(ROOT).as_posix()
                           for p in (OUT / 'recovery-compatibility').glob('*.png')],
    'limitations': ['Owner process needs restart/reload.',
                    'Actual live-account restoration and owner acceptance remain.',
                    'No owner save/session edit, live API request, device query/test, APK or deployment.',
                    'No main-index stage/commit/merge.',
                    'Initial sandbox certificate-store failures retained.',
                    'Pre-existing kart implementation and other concurrent work excluded from patch.']
}
(OUT / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'passing_checks': 261, 'patch_checks': checks,
                  'round_trip_exact': round_trip}))
