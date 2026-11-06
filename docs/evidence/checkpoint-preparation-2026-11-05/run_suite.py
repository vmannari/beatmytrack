"""Run retained offline rule/replay and native presentation checks sequentially."""
import json
from pathlib import Path
import subprocess
import sys

evidence = Path(__file__).resolve().parent
jobs = [
    ('coverage','test_checkpoint_road_coverage_prepared','headless'),
    ('rules','test_checkpoint_rules','headless'),
    ('notices','test_checkpoint_notices','headless'),
    ('notice-latency','test_checkpoint_notice_latency','headless'),
    ('bridges','test_checkpoint_bridge_layers','headless'),
    ('knot-notices','test_knot_checkpoint_notices','headless'),
    ('consistency','test_star_checkpoint_consistency','headless'),
    ('forgiveness','test_checkpoint_forgiveness','headless'),
    ('rewind','test_compact_rewind','headless'),
    ('retention','test_selective_scenery_budget','headless'),
    ('shortcuts','test_star_checkpoint_shortcuts_prepared','headless'),
    ('hairpin-gl','test_hairpin_checkpoints_prepared','gl_compatibility'),
    ('capture-gl','capture_checkpoint_preparation','gl_compatibility'),
    ('hairpin-mobile','test_hairpin_checkpoints_prepared','mobile'),
    ('capture-mobile','capture_checkpoint_preparation','mobile'),
]
results = []
for label,script,mode in jobs:
    command = [sys.executable,str(evidence/'run_check.py'),label,f'res://tests/{script}.gd','--frozen','--timeout','360']
    command += ['--headless'] if mode == 'headless' else ['--renderer',mode]
    status = subprocess.run(command,check=False).returncode
    results.append(dict(label=label,exit_code=status,command=command))
    (evidence/'suite.json').write_text(json.dumps(results,indent=2)+'\n')
    print(label,status,flush=True)
    if status: break
sys.exit(1 if any(row['exit_code'] for row in results) else 0)
