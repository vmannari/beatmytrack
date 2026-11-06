"""Demonstrate the actual-material regression against the task-start generator."""
import hashlib,json,subprocess,sys
from pathlib import Path
p=Path(__file__).resolve().parent
game=Path(json.loads((p/'frozen-project.json').read_text())['project'])
target=game/'track/surface_shader_variants.gd'
candidate=target.read_bytes()
try:
    target.write_bytes((p/'before/game/track/surface_shader_variants.gd').read_bytes())
    command=[sys.executable,str(p/'run_check.py'),'original-contract','res://tests/test_surface_shader_pruning.gd','--frozen','--headless','--timeout','60']
    result=subprocess.run(command)
    log=(p/'original-contract.log').read_text(errors='replace')
    assert result.returncode==1 and 'SURFACE_SHADER_PRUNING: 39 checks, 1 failures' in log and 'SCRIPT ERROR:' not in log
finally:
    target.write_bytes(candidate)
assert target.read_bytes()==candidate
(p/'original-control.json').write_text(json.dumps({'expected_exit':1,'checks':39,'expected_failures':1,'candidate_restored_exact':True,'restored_sha256':hashlib.sha256(candidate).hexdigest()},indent=2)+'\n')
print('Original retains the inactive radiance write; final candidate restored exactly.')
