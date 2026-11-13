"""Run the native capture with only this task's original runtime restored.

Mutations are restricted to the owned frozen project, and restored in finally.
"""
import json
from pathlib import Path
import subprocess
import sys

evidence = Path(__file__).resolve().parent
renderer = sys.argv[1] if len(sys.argv)>1 else 'gl_compatibility'
assert renderer in ('gl_compatibility','mobile')
root = evidence.parents[2]
game = Path(json.loads((evidence/'frozen-project.json').read_text())['project'])
assert game.resolve().is_relative_to((root/'build/checkpoint-preparation-20261105').resolve())
runtime = ['race/spline_gate_corridor.gd','race/track_session.gd','editor/editor_memory.gd']
saved = {name:(game/name).read_bytes() for name in runtime}
text = (game/'tests/capture_checkpoint_preparation.gd').read_text().replace('res://../build/checkpoint-preparation-output/','res://../build/checkpoint-preparation-control/')
(game/'tests/capture_checkpoint_control.gd').write_text(text,encoding='utf-8')
try:
    for name in runtime: (game/name).write_bytes((evidence/'before/game'/name).read_bytes())
    result = subprocess.run([sys.executable,str(evidence/'run_check.py'),'capture-control-'+renderer,'res://tests/capture_checkpoint_control.gd','--frozen','--renderer',renderer,'--timeout','360'],check=False)
finally:
    for name,data in saved.items(): (game/name).write_bytes(data)
assert all((game/name).read_bytes()==data for name,data in saved.items())
print('Owned frozen runtime restored byte-exact after original-source control.')
sys.exit(result.returncode)
