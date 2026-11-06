"""Collect actual receipts, assertions, exact comparisons and owned artifacts."""
import hashlib
import json
from pathlib import Path
import re
import shutil

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
game = Path(json.loads((evidence/'frozen-project.json').read_text())['project'])
runtime = ['game/race/spline_gate_corridor.gd','game/race/track_session.gd','game/race/checkpoint_layout_cache.gd','game/editor/editor_memory.gd']
source = {name:dict(current=hashlib.sha256((root/name).read_bytes()).hexdigest(),frozen=hashlib.sha256((game.parent/name).read_bytes()).hexdigest()) for name in runtime}
assert all(row['current'] == row['frozen'] for row in source.values())
rows = []
for path in sorted(evidence.glob('*-receipt.json')):
    receipt = json.loads(path.read_text())
    label = path.name.removesuffix('-receipt.json')
    log = (evidence/(label+'.log')).read_text(errors='replace')
    assertions = re.findall(r'([A-Z_]+):? (\d+) checks, (\d+) failures',log)
    rows.append(dict(label=label,exit_code=receipt['exit_code'],seconds=receipt['elapsed_seconds'],changed_sources=receipt['changed_sources'],assertions=assertions,
                     diagnostics=[line for line in log.splitlines() if 'ERROR:' in line or 'WARNING:' in line]))
artifacts = []
for directory in [game.parent/'build'/name for name in ('checkpoint-preparation-output','checkpoint-preparation-control','checkpoint-preparation-settled','hairpin-checkpoints-2026-10-18')]:
    for path in directory.rglob('*'):
        if not path.is_file(): continue
        target = evidence/'artifacts'/path.relative_to(game.parent/'build')
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(path,target)
        artifacts.append(dict(path=str(target.relative_to(root)),sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
result = dict(runtime_sources=source,runs=rows,artifacts=artifacts)
(evidence/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps([dict(label=row['label'],exit_code=row['exit_code'],assertions=row['assertions'],changed_sources=row['changed_sources']) for row in rows],indent=2))
