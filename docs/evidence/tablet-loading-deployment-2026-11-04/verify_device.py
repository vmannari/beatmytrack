"""Read-only deployment receipt and screenshots for the explicitly selected tablet."""
import hashlib
import json
import pathlib
import re
import subprocess
import time

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[2]
ADB = r'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe'
SERIAL = 'f0ba474a'
PACKAGE = 'org.circuit01.handlinglab'

def adb(*args, binary=False):
    result = subprocess.run([ADB, '-s', SERIAL, *args], capture_output=True, check=True)
    return result.stdout if binary else result.stdout.decode('utf-8', errors='replace')

apk = ROOT / 'build/tablet-loading-deployment-2026-11-04/source/build/android/circuit01-debug.apk'
before = json.loads((OUT / 'build-before.json').read_text(encoding='utf-8-sig'))
package = adb('shell', 'dumpsys', 'package', PACKAGE)
(OUT / 'package-after.txt').write_text(package, encoding='utf-8')
assert 'versionName=' + before['build_id'] in package
assert 'firstInstallTime=2026-10-08 22:15:46' in package
remote = adb('shell', 'pm', 'path', PACKAGE).strip().splitlines()[0].removeprefix('package:')
installed_hash = adb('shell', 'sha256sum', remote).split()[0]
local_hash = hashlib.sha256(apk.read_bytes()).hexdigest()
assert installed_hash == local_hash
pid = adb('shell', 'pidof', PACKAGE).strip()
assert pid
logs = adb('logcat', '-d', '--pid=' + pid, '-v', 'threadtime')
(OUT / 'startup-device.txt').write_text(logs, encoding='utf-8')
(OUT / 'tablet-launch.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
ready = 'APP_READY' in logs
errors = [line for line in logs.splitlines() if re.search(r'FATAL EXCEPTION|SCRIPT ERROR|Fatal signal|Parse Error', line)]
report = dict(device=SERIAL, package=PACKAGE, build_id=before['build_id'],
              apk_sha256=local_hash, installed_apk_sha256=installed_hash,
              apk_bytes=apk.stat().st_size, pid=pid, app_ready=ready,
              fatal_or_script_errors=errors, original_install_time_retained=True,
              install_method='adb install -r', tracks_synced=False,
              limits='Startup verification only; no touch, driving, thermal or loading-time benchmark.')
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
assert ready, 'APP_READY missing from retained process log'
assert not errors
