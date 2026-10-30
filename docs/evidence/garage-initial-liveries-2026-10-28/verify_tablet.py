import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
BASE = Path(__file__).resolve().parent
WORK = ROOT / 'build/tablet-garage-liveries-2026-10-28'
SOURCE = WORK / 'source'
ADB = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe'
SERIAL = 'f0ba474a'
PACKAGE = 'org.circuit01.handlinglab'


def adb(*args):
    return subprocess.check_output([str(ADB), '-s', SERIAL, *args], timeout=60)


def package():
    text = adb('shell', 'dumpsys', 'package', PACKAGE).decode(errors='replace')
    return {key: re.search(key + r'=([^\r\n]+)', text).group(1).strip()
            for key in ['versionName', 'firstInstallTime', 'lastUpdateTime']}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


mode = sys.argv[1]
if mode == 'before':
    data = dict(serial=SERIAL, model=adb('shell', 'getprop', 'ro.product.model').decode().strip(),
                android=adb('shell', 'getprop', 'ro.build.version.release').decode().strip(),
                abi=adb('shell', 'getprop', 'ro.product.cpu.abi').decode().strip(), package=package())
    assert data['model'] == 'OPD2403'
    (BASE / 'tablet-before.json').write_text(json.dumps(data, indent=2) + '\n')
elif mode == 'build':
    receipt = max((SOURCE / 'build/logs').glob('ExportAndroid-*/client-build-identity.json'), key=lambda p: p.stat().st_mtime)
    expected = json.loads(receipt.read_text(encoding='utf-8-sig'))
    env = os.environ.copy()
    env['GIT_DIR'] = str(ROOT / '.git')
    env['GIT_WORK_TREE'] = str(SOURCE)
    command = ". '" + str(SOURCE / 'scripts/build_identity.ps1') + "'; Write-ClientBuildIdentity '" + str(SOURCE) + "' '" + str(WORK / 'verified-identity') + "'"
    actual = subprocess.check_output(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command], env=env).decode().strip()
    assert actual == expected['build_id'], 'Source identity changed after export'
    apk = SOURCE / 'build/android/circuit01-debug.apk'
    aapt = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/build-tools/36.1.0/aapt.exe'
    badging = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)]).decode(errors='replace')
    headline = badging.splitlines()[0]
    assert "name='" + PACKAGE + "'" in headline
    assert "versionName='" + actual + "'" in headline
    changes = {}
    concurrent = {}
    manifest = json.loads((WORK / 'source-manifest.json').read_text())
    for name, digest in manifest.items():
        live = sha(ROOT / name)
        if live != digest:
            concurrent[name] = dict(snapshot=digest, current=live)
        current = sha(SOURCE / name)
        if current != digest:
            assert name in ['game/core/build_identity.gd', 'game/project.godot'] or name.startswith('game/assets/garage/previews_v1/'), name
            changes[name] = dict(before=digest, packaged=current)
    reviewed = json.loads((BASE / 'report.json').read_text())
    for name in ['game/core/app.gd', 'game/ui/garage_cached_thumbnail.gd']:
        assert sha(SOURCE / name) == reviewed['sources'][name]['after'], 'Garage fix differs from reviewed source: ' + name
    data = dict(**expected, apk_sha256=sha(apk), apk_bytes=apk.stat().st_size,
                package=headline, source_identity_matches=True, reviewed_garage_fix_matches=True,
                concurrent_workspace_changes=concurrent,
                snapshot_derivatives=changes, apk_path=str(apk))
    (BASE / 'tablet-build.json').write_text(json.dumps(data, indent=2) + '\n')
elif mode == 'after':
    before = json.loads((BASE / 'tablet-before.json').read_text())
    build = json.loads((BASE / 'tablet-build.json').read_text())
    after = package()
    assert after['versionName'] == build['build_id']
    assert after['firstInstallTime'] == before['package']['firstInstallTime']
    remote = adb('shell', 'pm', 'path', PACKAGE).decode().strip().removeprefix('package:')
    assert re.fullmatch(r'/data/app/[A-Za-z0-9_./+=~\-]+\.apk', remote)
    installed = adb('shell', 'sha256sum', remote).decode().split()[0]
    assert installed == build['apk_sha256']
    process = adb('shell', 'pidof', PACKAGE).decode().strip().split()[0]
    assert process.isdecimal()
    policy = adb('shell', 'dumpsys', 'window', 'policy').decode(errors='replace')
    locked = bool(re.search(r'^\s*showing=true\s*$', policy, re.M) and re.search(r'^\s*secure=true\s*$', policy, re.M))
    if locked:
        data = dict(serial=SERIAL, model=before['model'], package=after, process_id=process,
                    installed_apk_sha256=installed, installed_version_matches=True,
                    first_install_time_unchanged=True, app_ready=False,
                    startup_status='blocked_by_secure_lock_screen')
        (BASE / 'tablet-after.json').write_text(json.dumps(data, indent=2) + '\n')
        print(json.dumps(data))
        sys.exit(3)
    logs = ''
    for _ in range(30):
        logs = adb('logcat', '-d', '--pid=' + process, '-v', 'brief').decode(errors='replace')
        if 'APP_READY' in logs:
            break
        time.sleep(1)
    (WORK / 'startup-private.log').write_text(logs, encoding='utf-8')
    errors = [line for line in logs.splitlines() if re.search(r'SCRIPT ERROR:|(^|\s)ERROR:|FATAL EXCEPTION', line)]
    assert 'APP_READY' in logs, 'Application startup did not finish'
    assert not errors, 'Inspect local process log for runtime errors'
    adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    adb('shell', 'wm', 'dismiss-keyguard')
    time.sleep(1)
    (BASE / 'tablet-launch.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    data = dict(serial=SERIAL, model=before['model'], package=after, process_id=process,
                installed_apk_sha256=installed, installed_version_matches=True,
                first_install_time_unchanged=True, app_ready=True, startup_errors=len(errors))
    (BASE / 'tablet-after.json').write_text(json.dumps(data, indent=2) + '\n')
else:
    raise ValueError(mode)
print(json.dumps(data))
