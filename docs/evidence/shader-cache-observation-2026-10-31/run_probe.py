"""Run one disposable owned-App shader-cache observation.

This diagnostic intercepts GL function pointers in this child process only.
It must never be loaded into the owner's editor/game. On-disk app data and
reports live under this script's build directory. No GL behavior is replaced.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[2]
lab = Path(__file__).resolve().parent
engine = Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe')
expected = 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
if len(sys.argv) != 2 or sys.argv[1] not in ('control', 'trace', 'trace2', 'control2'):
    raise SystemExit('Usage: python run_probe.py control|trace|trace2|control2')
label = sys.argv[1]
tracing = label.startswith('trace')
if hashlib.sha256(engine.read_bytes()).hexdigest() != expected:
    raise SystemExit('Pinned engine identity changed; diagnostic hook not allowed')
target = lab / ('run-' + label)
target.mkdir(exist_ok=False)
(target / 'user').mkdir()
(target / 'output').mkdir()
template = (lab / 'cache_profile.gd').read_text(encoding='utf-8')
template = template.replace('res://../build/shader-cache-observation-20261031/output',
                            'res://../build/shader-cache-observation-20261031/run-' + label + '/output')
(target / 'profile.gd').write_text(template, encoding='utf-8', newline='\n')
env = {key: value for key, value in os.environ.items() if not key.startswith('BMT_')}
env.update(APPDATA=str(target / 'user'), LOCALAPPDATA=str(target / 'user'),
           BMT_API_URL='', BMT_CACHE_TRACE_REPORT=str(target / 'trace.json'))
args = [sys.executable, str(root / 'scripts/run_no_crash_dialog.py'), '--', str(engine),
        '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--path',
        str(root / 'game'), '--script', str(target / 'profile.gd'), '--', '--only-star']
if tracing:
    args.append('--cache-trace')
tracked = ['game/core/app.gd', 'game/core/game.gd', 'game/vehicle/sand_dust.gd',
           'game/track/track_theme.gd', 'game/race/world_render_preparation.gd',
           'game/tests/profile_runtime_correctness.gd']
def hashes():
    return {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in tracked}
result = {'label': label, 'engine_sha256': expected, 'command': args, 'source_hashes_start': hashes()}
started = time.monotonic()
with (target / 'console.log').open('wb') as stream:
    process = subprocess.Popen(args, cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT)
    result['wrapper_pid'] = process.pid
    try:
        result['exit_code'] = process.wait(timeout=240)
    except subprocess.TimeoutExpired:
        result['timeout'] = True
        # Only terminate the tree created by this runner.
        subprocess.run(['taskkill.exe', '/PID', str(process.pid), '/T', '/F'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        process.wait(timeout=15)
        result['exit_code'] = process.returncode
result['wall_seconds'] = time.monotonic() - started
result['source_hashes_end'] = hashes()
log = (target / 'console.log').read_text(encoding='utf-8', errors='replace')
godot_log = target / 'user' / 'Circuit01Lab' / 'logs' / 'godot.log'
if godot_log.is_file():
    log += '\n' + godot_log.read_text(encoding='utf-8', errors='replace')
result['profile_pass'] = 'RUNTIME_PROFILE: 10 checks, 0 failures' in log
if tracing and (target / 'trace.json').is_file():
    trace = json.loads((target / 'trace.json').read_text(encoding='utf-8'))
    result['hook_installed'] = trace['installed']
    result['events_total'] = trace['events_total']
    result['events_dropped'] = trace['events_dropped']
    result['slots'] = trace.get('slots')
    result['slots_restored'] = trace.get('slots_restored')
    result['valid_hook'] = trace['installed'] and trace['events_dropped'] == 0 and trace.get('slots') == trace.get('slots_restored') and bool(trace.get('slots'))
else:
    result['valid_hook'] = not tracing
(target / 'execution.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
if result.get('timeout') or result['exit_code'] != 0 or not result['profile_pass'] or not result['valid_hook']:
    raise SystemExit(1)
