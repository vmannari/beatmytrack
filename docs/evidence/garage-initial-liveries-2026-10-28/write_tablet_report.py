import json
from pathlib import Path
import re

BASE = Path(__file__).resolve().parent
ROOT = next(p for p in BASE.parents if (p / 'godot-version.txt').exists())
WORK = ROOT / 'build/tablet-garage-liveries-2026-10-28'
build = json.loads((BASE / 'tablet-build.json').read_text())
before = json.loads((BASE / 'tablet-before.json').read_text())
after = json.loads((BASE / 'tablet-after.json').read_text())
assert after['installed_version_matches'] and after['first_install_time_unchanged']
assert after['installed_apk_sha256'] == build['apk_sha256']
logs = {}
for name in ['bake', 'export', 'install', 'launch']:
    raw = (WORK / (name + '.log')).read_bytes()
    text = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig', errors='replace')
    text = re.sub(r'\x1b\[[0-9;]*m', '', text)
    (BASE / ('tablet-' + name + '.log')).write_text(text, encoding='utf-8')
    logs[name] = text
assert 'Success' in logs['install']
assert 'Status: ok' in logs['launch']
checks = {}
for label in ['DRIVING_TESTS', 'CATALOG_TESTS', 'MENU_PRESENTATION_TESTS']:
    match = re.search(label + r': (\d+) checks, (\d+) failures', logs['export'])
    assert match and int(match[2]) == 0, label
    checks[label] = dict(checks=int(match[1]), failures=int(match[2]))
assert 'APP_READY' in logs['export']
report = dict(date='2026-10-28', requirements=['GL01', 'GL02', 'TD01', 'TD02', 'TD03'],
              request='deploy to tablet', build=build, device_before=before, device_after=after,
              validation=dict(asset_import='passed', desktop_startup='APP_READY', tests=checks,
                              native_preview_bake='seven images; 126 current source guards', full_regression=False),
              install=dict(method='adb -s f0ba474a install -r', result='Success',
                           exact_installed_hash_verified=True, first_install_time_unchanged=True,
                           uninstall=False, data_clear=False, track_sync=False,
                           completed_installer_wrapper_closed_after_success=True),
              launch=dict(android_status='ok', launch_state='COLD', total_ms=956,
                          app_ready=after['app_ready'], startup_status=after.get('startup_status', 'verified')),
              limitations=['Owner Garage/driving acceptance remains.' if after['app_ready'] else 'The secure Android keyguard prevented rendered-game/startup acceptance until the owner unlocks.',
                           'New workspace changes during compilation are recorded and excluded from the frozen build.',
                           'Preview derivatives were refreshed only in the deployment snapshot.',
                           'No driving, provider sign-in, purchase, cloud deployment, data clearing or track synchronization.'],
              commands=[['python', str((BASE / 'prepare_tablet.py').relative_to(ROOT))],
                        *[['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                           str((BASE / 'run_tablet_build.ps1').relative_to(ROOT)), '-Step', step]
                          for step in ['Bake', 'Export', 'Install', 'Launch']],
                        *[['python', str((BASE / 'verify_tablet.py').relative_to(ROOT)), step]
                          for step in ['before', 'build', 'after']]],
              initial_findings=['Original export guard rejected stale electric.tres preview provenance.',
                                'First build comparison detected concurrent root edits; frozen source identity and the reviewed Garage sources match.',
                                'Two startup probes did not reach APP_READY while Android was locked/asleep; black captures and private logs remain under build/.',
                                'Normal wake/dismiss commands did not dismiss the secure keyguard; owner was asked to unlock.'])
(BASE / 'tablet-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(installed=True, exact_apk=True, app_ready=after['app_ready'],
                     build_id=build['build_id'], remaining=report['launch']['startup_status'])))
