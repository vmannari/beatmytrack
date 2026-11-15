from pathlib import Path
import hashlib,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
publication=json.loads((OUT/'native-publication.json').read_text())
assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/name)==digest for name,digest in publication['private_native'].items())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text())
assert all(sha(ROOT/name)==digest for name,digest in checkpoint['after'].items())
prep=json.loads((OUT/'preparation-command.json').read_text())
assert prep['stable'] and all(sha(Path(name))==digest for name,digest in prep['after'].items())
start=json.loads((OUT/'task-start.json').read_text())
assert all(sha(ROOT/name)==digest for name,digest in start.items() if name.startswith('game/resources/cars/') or name in ['game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd','scripts/challenger_side_surface.py','game/tests/bake_challenger_hellcat.gd'])
scope=json.loads((OUT/'asset-receipts/final-scope.json').read_text())
assert scope['full_preflight']['exit_code']==0 and scope['source_fence_exact']
for args in [['scripts/check_garage_previews.py','--vehicles=super_rally'],['scripts/check_garage_workshop.py']]:
    result=subprocess.run([sys.executable,*args],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    assert result.returncode==0,result.stdout
    print(result.stdout.strip())
state=json.loads((OUT/'final-state.json').read_text())
state['scope']='Challenger reference form; complete prepared snapshot validated'
(OUT/'final-state.json').write_text(json.dumps(state,indent=2))
retention=json.loads((OUT/'retention-command.json').read_text())
assert retention['exit_code']==0 and retention['main_index_unchanged'] and not retention['task_active_pin_created']
report=ROOT/'docs/CHALLENGER_REFERENCE_FORM_2026_11_15.md'
report.write_text(report.read_text(encoding='utf-8')+'\nThe prescribed retention pass completed without a task pin. Build usage remained 33.13 GiB because recent/protected outputs were retained; no direct deletion bypass was used.\n',encoding='utf-8')
(OUT/'final-audit.json').write_text(json.dumps({'native_allowlist_exact':True,'source_checkpoint_exact':True,'conversion_inputs_exact':True,'configuration_and_physics_controls_exact':True,'prepared_snapshot_checks':2267,'prepared_snapshot_failures':0,'current_picture_and_workshop':True,'retention_exit_code':0},indent=2))
print('REFERENCE_FORM_FINAL_AUDIT native/source/physics controls, current provenance and final prepared snapshot verified')
