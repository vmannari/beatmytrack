from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BAKE=ROOT/'build/challenger-refinement-assets';PRESENT=ROOT/'build/challenger-refinement-presentation'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
commands={p.stem.removesuffix('-command'):read(p) for p in BAKE.glob('*-command.json')}
assert len(commands)==15
assert all(r['exit_code']==0 and r['script_errors']==0 for r in commands.values())
(OUT/'assets-commands.json').write_text(json.dumps(commands,indent=2),encoding='utf-8')
for name in ['source-receipt.json','identity-before.json','client-build-identity.json','prepared.log','picture-preflight.log']:
    shutil.copyfile(BAKE/name,OUT/('assets-'+name))
fence=read(BAKE/'source-receipt.json');assert fence['before']==fence['after'] and not fence['changed']
presentation=read(PRESENT/'source-receipt.json')
assert presentation['before']==presentation['after'] and presentation['geometry_revisions_exact']
assert presentation['delta_from_geometry_bake']==['game/ui/car_showroom.gd']
for f,h in presentation['after'].items():assert sha(ROOT/f)==h,f
for f,h in fence['after'].items():
    if f!='game/ui/car_showroom.gd':assert presentation['after'][f]==h,f
presentation_commands={p.stem.removesuffix('-command'):read(p) for p in PRESENT.glob('*-command.json')}
assert len(presentation_commands)==7 and all(r['exit_code']==0 and r['script_errors']==0 for r in presentation_commands.values())
(OUT/'presentation-commands.json').write_text(json.dumps(presentation_commands,indent=2),encoding='utf-8')
shutil.copyfile(PRESENT/'source-receipt.json',OUT/'presentation-source-receipt.json')
shutil.copyfile(PRESENT/'client-build-identity.json',OUT/'presentation-identity.json')
assert read(BAKE/'identity-before.json')['modular_car_sha256']==read(BAKE/'client-build-identity.json')['modular_car_sha256']
labels=['native-final','geometry','fitted-final','modules','physics','wash-final','driving','parser-final','opaque-gl','opaque-mobile','app-gl-final','app-mobile-final','credit','final-import','final-native','shadow-switch']
checks={label:read(OUT/(label+'-command.json')) for label in labels}
assert all(r['exit_code']==0 and r['script_errors']==0 for r in checks.values())
prep=read(OUT/'preparation-command.json');assert prep['stable'] and prep['exit_code']==0
for f,h in prep['after'].items():assert sha(Path(f))==h,f
pictures={f:{'before':h,'after':sha(ROOT/f),'exact':h==sha(ROOT/f)} for f,h in read(OUT/'pictures-before-refresh.json').items()}
assert all(v['exact'] for v in pictures.values())
(OUT/'unrelated-picture-controls.json').write_text(json.dumps(pictures,indent=2),encoding='utf-8')
old=read(ROOT/'docs/evidence/challenger-hellcat-2026-11-09/final/gl_compatibility/geometry.json')
new=read(OUT/'final/gl_compatibility/geometry.json');assert old['compact']==new['compact']
result={'stable_asset_inputs':len(fence['before']),'asset_commands':len(commands),'presentation_commands':len(presentation_commands),'final_commands':checks,
 'preparation_inputs_exact':True,'normal_rally_geometry':{'before':old['compact'],'after':new['compact'],'exact':True},
 'opacity':{r:read(OUT/'opaque'/r/'acceptance.json') for r in ['gl_compatibility','mobile']},
 'actual_app':{r:read(OUT/'app-final'/r/'acceptance.json') for r in ['gl_compatibility','mobile']},
 'limits':'Desktop proof only; owner appearance and device qualification remain; no owner save/process, backend, APK/install, device or main-index operation.'}
assert all(v['failures']==0 for group in [result['opacity'],result['actual_app']] for v in group.values())
(OUT/'final-acceptance.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('CHALLENGER_REFINEMENT_FINAL:',len(fence['before']),'stable inputs;',len(commands),'asset commands;',len(checks),'acceptance commands; exact Rally geometry and',len(pictures),'picture controls')
