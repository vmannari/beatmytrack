"""Run the native investigation through the pinned entry point with private saves."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
renderer = sys.argv[1] if len(sys.argv) > 1 else 'gl_compatibility'
profile = root / 'build/volt-night-roof-20261106' / renderer
(profile / 'Circuit01Lab').mkdir(parents=True, exist_ok=True)
(profile / 'Circuit01Lab/backend.cfg').write_text('[backend]\nurl=""\n', encoding='utf-8')
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL='')
paths = [root / path for path in (
    'game/vehicle/electric_glass.gdshader', 'game/vehicle/electric_reference_cabin.gd',
    'game/vehicle/car_visual.gd', 'game/core/game.gd', 'game/track/track_theme.gd',
    'game/tests/review_volt_night_roof.gd')]
def hashes():
    return {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
command = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(root / 'scripts/dev.ps1'),
           '-Action', 'TestScript', '-ScriptPath', 'res://tests/review_volt_night_roof.gd',
           '-Graphical', '-RenderingMethod', renderer, '-CommandTimeoutSeconds', '180']
receipt = {'command': command, 'profile': str(profile), 'before': hashes()}
start = time.monotonic()
with (evidence / (renderer + '.log')).open('w', encoding='utf-8') as log:
    result = subprocess.run(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
receipt.update(exit_code=result.returncode, elapsed_seconds=time.monotonic()-start, after=hashes())
receipt['sources_unchanged'] = receipt['before'] == receipt['after']
(evidence / (renderer + '-receipt.json')).write_text(json.dumps(receipt, indent=2), encoding='utf-8')
print(json.dumps(receipt))
sys.exit(result.returncode)
