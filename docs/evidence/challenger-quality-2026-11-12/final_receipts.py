from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BAKE=ROOT/'build/challenger-quality-assets'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
commands={p.stem.removesuffix('-command'):read(p) for p in BAKE.glob('*-command.json')}
assert len(commands)==15 and all(r['exit_code']==0 and r['script_errors']==0 for r in commands.values())
(OUT/'assets-commands.json').write_text(json.dumps(commands,indent=2),encoding='utf-8')
for name in ['source-receipt.json','identity-before.json','client-build-identity.json','prepared.log','picture-preflight.log']:
 shutil.copyfile(BAKE/name,OUT/('assets-'+name))
fence=read(BAKE/'source-receipt.json');assert fence['before']==fence['after'] and not fence['changed']
for f,h in fence['after'].items():assert sha(ROOT/f)==h,f
assert read(BAKE/'identity-before.json')['modular_car_sha256']==read(BAKE/'client-build-identity.json')['modular_car_sha256']
labels=['measured-native','geometry','fitted-final','modules','physics','wash','driving','parser','opaque-gl','opaque-mobile','app-gl','app-mobile','credit','final-import','review-gl','review-mobile','shadow-switch','preview-repeat','preview-pixels','closeout-prepared','closeout-pictures']
checks={label:read(OUT/(label+'-command.json')) for label in labels}
assert all(r['exit_code']==0 and r['script_errors']==0 for r in checks.values())
prep=read(OUT/'preparation-command.json');assert prep['stable'] and prep['exit_code']==0
for f,h in prep['after'].items():assert sha(Path(f))==h,f
pictures={f:{'before':h,'after':sha(ROOT/f),'exact':h==sha(ROOT/f)} for f,h in read(OUT/'pictures-before.json').items()}
changed={f for f,v in pictures.items() if not v['exact']}
expected={'game/assets/garage/previews_v1/kart.png','game/assets/news/vehicles/kart.png','game/assets/menu/header_cars_v1/kart.png','game/assets/menu/kart_illustration_v1.png'}
assert changed==expected,changed
repeat=read(OUT/'preview-repeat-pixels.json')
assert repeat['super_rally']['changed_pixels']==0 and repeat['kart']['changed_pixels']==0

(OUT/'unrelated-picture-controls.json').write_text(json.dumps(pictures,indent=2),encoding='utf-8')
old=read(ROOT/'docs/evidence/challenger-refinement-2026-11-09/final/gl_compatibility/geometry.json')
new=read(OUT/'final/gl_compatibility/geometry.json');assert old['compact']==new['compact']
result={'stable_asset_inputs':len(fence['before']),'asset_commands':len(commands),'final_commands':checks,
 'preparation_inputs_exact':True,'picture_controls':{'exact':len(pictures)-len(changed),'refreshed':sorted(changed),'twenty_byte_exact_gate_met':False,'repeat_pixels':repeat},'normal_rally_geometry':{'before':old['compact'],'after':new['compact'],'exact':True},
 'opacity':{r:read(OUT/'opaque'/r/'acceptance.json') for r in ['gl_compatibility','mobile']},
 'actual_app':{r:read(OUT/'app'/r/'acceptance.json') for r in ['gl_compatibility','mobile']},
 'limits':'Quality improvement; no AAA certification or device-performance claim. Owner appearance/reload and device qualification remain. No owner save/process, backend, APK/install, device or main-index operation.'}
assert all(v['failures']==0 for group in [result['opacity'],result['actual_app']] for v in group.values())
(OUT/'final-acceptance.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('CHALLENGER_QUALITY_FINAL:',len(fence['before']),'stable inputs;',len(commands),'asset commands;',len(checks),'acceptance commands; exact Rally geometry and',len(pictures),'picture controls (16 exact, 4 concurrent Kart updates)')
