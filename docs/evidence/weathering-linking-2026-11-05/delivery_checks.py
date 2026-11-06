"""Require real coverage and unchanged shipping weathering before recording the experiment."""
import hashlib,json,re
from pathlib import Path
p=Path(__file__).resolve().parent
def read(name): return json.loads((p/name).read_text())
summary=read('summary.json')
assert all(summary['runtime_unchanged'].values())
accepted={k:r for k,r in summary['receipts'].items() if k!='candidate-pine-lap-receipt'}
assert all(r['exit_code']==0 and r['sources_unchanged'] for r in accepted.values())
assert len(summary['app'])==4
assert all(r['programs']=={'other':175,'burley':6,'toon':6} for r in summary['app'].values())
assert all(r['assertions']==[['9','0']] and len(r['rows'])==2 for r in summary['app'].values())
pixels=read('rear-pixels-visible/pixels.json')
assert pixels['checks']==112 and pixels['failures']==0 and len(pixels['rows'])==36
assert all(r['difference']['changed']==0 and r['control']['changed']==0 for r in pixels['rows'])
visible=[r['visibility']['changed'] for r in pixels['rows'] if 'visibility' in r]
assert len(visible)==3 and min(visible)>0
lap=read('candidate-pine-final.json')
assert lap['checks']>0 and lap['failures']==0 and len(lap['first_laps'])==1
assert lap['first_laps'][0]['completed_laps']>=1 and lap['first_laps'][0]['contacts']==0
g=Path(read('frozen-project.json')['project'])
assert (g/'core/game.gd').read_bytes()==(p/'before/game/core/game.gd').read_bytes()
errors={}
for path in sorted(p.glob('*.log')):
    lines=path.read_text(errors='replace').splitlines()
    errors[path.name]=[line for line in lines if any(word in line for word in ('ERROR:','WARNING:','leaked','RACE_HITCH'))]
result={'shipping_weathering_unchanged':True,'owned_app_hook_restored':True,
    'accepted_processes':len(accepted),'excluded_initial_lap_receipt':summary['receipts'].get('candidate-pine-lap-receipt'),'app_assertions':36,'final_pixel_assertions':112,
    'initial_pixel_assertions':109,'lap_assertions':lap['checks'],
    'final_targeted_assertions':36+112+lap['checks'],
    'visibility_pixels':visible,'lap':lap['first_laps'][0],'log_findings':errors}
(p/'delivery-checks.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
