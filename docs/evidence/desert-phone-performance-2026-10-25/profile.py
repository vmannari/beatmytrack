from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--name', required=True)
parser.add_argument('--features', default='baseline,particles,baseline,terrain_flat,road_flat,half_scale,baseline')
parser.add_argument('--seconds', type=int, default=20)
parser.add_argument('--track', default='track_3e26605a8a90165e')
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.name)
root = Path(__file__).resolve().parents[2]
work = Path(__file__).resolve().parent
out = root / 'docs/evidence/desert-phone-performance-2026-10-25' / args.name
out.mkdir(parents=True, exist_ok=False)
private = work / args.name
private.mkdir()
adb = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe'
serial = 'PRQKU4U4PREQNRWG'
package = 'org.circuit01.handlinglab'


def run(*command, timeout=60):
    result = subprocess.run([str(adb), '-s', serial, *command], capture_output=True, timeout=timeout)
    if result.returncode:
        (private / 'adb-error.log').write_bytes(result.stdout + result.stderr)
        raise RuntimeError(f'ADB failed: {command[:3]}')
    return result.stdout


assert run('get-state').strip() == b'device'
assert run('shell', 'getprop', 'ro.product.model').strip() == b'DN2103'
lock = run('shell', 'dumpsys', 'window', 'policy').decode(errors='replace')
assert 'mIsShowing=true' not in lock, 'Phone is locked; wait for owner unlock before profiling'
files = run('shell', 'run-as', package, 'ls', 'files').decode().splitlines()
assert 'mobile_probe.json' not in files and 'mobile_probe_results.json' not in files, 'Preserve existing diagnostics'
(out / 'package-before.txt').write_bytes(run('shell', 'dumpsys', 'package', package))
(out / 'thermal-before.txt').write_bytes(run('shell', 'dumpsys', 'thermalservice'))
(out / 'battery-before.txt').write_bytes(run('shell', 'dumpsys', 'battery'))
config = {'track_id': args.track, 'seconds': args.seconds, 'sustained': True, 'use_game_scale': True, 'feature_profile': True, 'touch_stress': False, 'features': args.features.split(',')}
(out / 'config.json').write_text(json.dumps(config), encoding='ascii')
owned = False
try:
    run('shell', 'am', 'force-stop', package)
    run('push', str(out / 'config.json'), '/data/local/tmp/desert-perf-probe.json')
    run('shell', 'run-as', package, 'cp', '/data/local/tmp/desert-perf-probe.json', 'files/mobile_probe.json')
    owned = True
    run('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    (out / 'launch.txt').write_bytes(run('shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', '-p', package))
    deadline = time.monotonic() + 180 + (args.seconds + 5) * len(config['features'])
    done = 0
    last_progress = time.monotonic()
    while time.monotonic() < deadline:
        time.sleep(5)
        current = run('shell', 'run-as', package, 'ls', 'files').decode().splitlines()
        if 'mobile_probe_results.json' in current:
            raw = run('exec-out', 'run-as', package, 'cat', 'files/mobile_probe_results.json')
            try:
                reports = json.loads(raw)
            except ValueError:
                continue
            (out / 'results.json').write_bytes(raw)
            for report in reports[done:]:
                print(json.dumps({key: report.get(key) for key in ['disabled_feature', 'frame_median_ms', 'frame_p95_ms', 'frame_p99_ms', 'frame_max_ms', 'process_median_ms', 'physics_median_ms', 'driven_metres', 'paused_frames', 'vehicle', 'clock_reference_query_ms', 'clock_reference_error_ms']}), flush=True)
            done = len(reports)
            if done == len(config['features']):
                break
        if time.monotonic() - last_progress >= 30:
            print(f'{args.name}: waiting, completed {done}/{len(config["features"])} stages', flush=True)
            last_progress = time.monotonic()
    pid = run('shell', 'pidof', package).decode().strip().split()[0]
    (private / 'startup.log').write_bytes(run('logcat', '-d', '--pid=' + pid, '-v', 'brief'))
    (out / 'phone.png').write_bytes(run('exec-out', 'screencap', '-p'))
    (out / 'thermal-after.txt').write_bytes(run('shell', 'dumpsys', 'thermalservice'))
    (out / 'battery-after.txt').write_bytes(run('shell', 'dumpsys', 'battery'))
    assert done == len(config['features']), f'Incomplete profile: {done}/{len(config["features"])}; inspect private startup log'
    assert all(report['paused_frames'] == 0 and report['driven_metres'] > 10 for report in reports), 'Invalid moving workload'
    assert all(report.get('clock_reference_error_ms', 0) <= 50 for report in reports), 'Wind phase differs by more than one 20Hz envelope sample'
finally:
    if owned:
        run('shell', 'am', 'force-stop', package)
        run('shell', 'run-as', package, 'rm', '-f', 'files/mobile_probe.json', 'files/mobile_probe_results.json')
        run('shell', 'rm', '-f', '/data/local/tmp/desert-perf-probe.json')
        run('shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', '-p', package)
        print('Normal play restored; task diagnostic markers removed', flush=True)
