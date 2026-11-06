"""Pinned offline checks and scoped baking; private profile and source receipts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

p = argparse.ArgumentParser(allow_abbrev=False)
p.add_argument('label')
p.add_argument('script')
p.add_argument('--renderer', default='gl_compatibility')
p.add_argument('--native', action='store_true')
p.add_argument('--dev', action='store_true')
p.add_argument('--verbose', action='store_true')
p.add_argument('--timeout', type=int, default=240)
args, extra = p.parse_known_args()
evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
profile = root / 'build/volt-night-glass-shape-20261106' / args.label
(profile / 'Circuit01Lab').mkdir(parents=True, exist_ok=True)
(profile / 'Circuit01Lab/backend.cfg').write_text('[backend]\nurl=""\n', encoding='utf-8')
output = evidence / args.label
output.mkdir(exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL='', BMT_VOLT_GLASS_OUTPUT=str(output))
godot = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
assert subprocess.check_output([sys.executable, str(root / 'scripts/run_no_crash_dialog.py'), '--', godot, '--version'], text=True).strip() == (root / 'godot-version.txt').read_text().strip()
command = [sys.executable, str(root / 'scripts/run_no_crash_dialog.py'), '--', godot,
           '--path', str(root / 'game'), '--audio-driver', 'Dummy', '--rendering-method', args.renderer,
           *([] if args.native else ['--headless']), *(['--verbose'] if args.verbose else []), '--script', args.script, '--', *extra]
if args.dev:
    assert not extra
    command = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(root / 'scripts/dev.ps1'),
               '-Action', 'TestScript', '-ScriptPath', args.script, '-RenderingMethod', args.renderer,
               '-CommandTimeoutSeconds', str(args.timeout), *(['-Graphical'] if args.native else [])]
def hashes():
    files = [root / path for path in ('game/vehicle/electric_glass.gdshader', 'game/race/electric_glass_lighting.gd',
                                    'game/core/game.gd', 'game/tests/test_volt_night_glass.gd',
                                    'game/tests/test_volt_night_windows.gd', 'game/tests/test_volt_night_glass_shape.gd')]
    return {path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
receipt = {'command': command, 'profile': str(profile), 'before': hashes()}
start = time.monotonic()
with (evidence / (args.label + '.log')).open('w', encoding='utf-8') as log:
    process = subprocess.Popen(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
    receipt['owned_pid'] = process.pid
    try:
        code = process.wait(timeout=args.timeout+60)
    except subprocess.TimeoutExpired:
        cleanup = subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True, text=True)
        receipt['timeout_cleanup'] = {'exit_code':cleanup.returncode, 'stdout':cleanup.stdout, 'stderr':cleanup.stderr}
        code = 124
receipt.update(exit_code=code, elapsed_seconds=time.monotonic()-start, after=hashes())
receipt['sources_unchanged'] = receipt['before'] == receipt['after']
receipt['script_errors'] = [line for line in (evidence / (args.label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines()
                            if line.startswith(('SCRIPT ERROR:', 'SHADER ERROR:'))]
(evidence / (args.label + '-receipt.json')).write_text(json.dumps(receipt, indent=2), encoding='utf-8')
print(json.dumps({key: receipt[key] for key in ('exit_code','elapsed_seconds','sources_unchanged','script_errors')}))
sys.exit(code or bool(receipt['script_errors']))
