from pathlib import Path
import json,subprocess,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
label=sys.argv[1];receipt=json.loads((OUT/(label+'-command.json')).read_text())
assert receipt['process_exit_code']==0 and receipt['script_errors']==0
assert receipt['changed_inputs'] and all(p.startswith('game/ui/') for p in receipt['changed_inputs'])
target=ROOT/'build/challenger-continuous-side-2026-11-15'/(label+'-route-input.json')
target.write_text(json.dumps(receipt['changed_inputs']))
command=[sys.executable,str(OUT/'run_check.py'),label+'-routes','res://../docs/evidence/challenger-continuous-side-2026-11-15/check_routes.gd','--headless','--audio-driver','Dummy','--','--input=res://../build/challenger-continuous-side-2026-11-15/'+target.name]
result=subprocess.run(command,cwd=ROOT);assert result.returncode==0
routes=json.loads(Path(str(target)+'.routes.json').read_text())
assert set(routes)==set(receipt['changed_inputs']) and all(not ids for ids in routes.values())
if label.startswith('app-'):
    app=json.loads((ROOT/'build/challenger-continuous-side-2026-11-15/app/mobile/acceptance.json').read_text())
    assert app['checks']==13 and app['failures']==0
else:
    folder=ROOT/'build/challenger-continuous-side-2026-11-15/views-final-close/mobile/full'
    model=json.loads((folder/'model-path.json').read_text())
    assert model['prepared'] and not model['candidate'] and model['cache_hits']['base']+model['cache_hits']['garage']>0
(OUT/(label+'-model-scope.json')).write_text(json.dumps({'original_broad_fence_rejected':True,
    'actual_process_exit_zero':True,'script_errors':0,'changed_ui_model_routes':routes,
    'all_model_inputs_unchanged_during_capture':True,'actual_app_assertions_pass':label.startswith('app-'),
    'no_whole_ui_stability_claim':True},indent=2))
print('MODEL_CAPTURE_QUALIFIED unconsumed UI changes; original broad rejection retained')
