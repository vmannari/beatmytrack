import json
from pathlib import Path
import subprocess
import sys
root = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
mode, label, scale = sys.argv[1:4]
folder = root / ('build/persistent-pictures-' + label)
base = Path(__file__).resolve().parent
for phase in ['seed', 'reuse']:
    command = [sys.executable, str(base / 'run_checks.py'), label + '-' + phase,
               'test_garage_persistent_pictures.gd', mode, '--phase=' + phase,
               '--scale=' + scale, '--cache=' + str(folder)]
    subprocess.run(command, cwd=root, check=True)
seed = json.loads((base / (label + '-seed') / 'seed.json').read_text())
reuse = json.loads((base / (label + '-reuse') / 'reuse.json').read_text())
assert seed['preview_revision'] == reuse['preview_revision'], 'Visual inputs changed between processes'
assert seed['pixel_hashes'] == reuse['pixel_hashes']
(base / (label + '-pair.json')).write_text(json.dumps({'seed': seed, 'reuse': reuse}, indent=2))
print('PAIR_PASS:', label, seed['ready_ms'], reuse['ready_ms'], flush=True)
