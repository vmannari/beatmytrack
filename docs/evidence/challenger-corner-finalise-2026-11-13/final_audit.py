"""Audit finalisation controls and retain current, scoped acceptance receipts."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-corner-finalise-2026-11-13/assets'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
original=json.loads((OUT/'task-start-controls.json').read_text())
controls={p:sha(ROOT/p) for p in original}
changes=[p for p in original if controls[p]!=original[p]]
assert not [p for p in changes if p.replace('\\','/')!='.git/index'],changes
fence=json.loads((BUILD/'source-receipt.json').read_text())
live_changes=[p for p,h in fence['after'].items() if sha(ROOT/p)!=h]
assert not fence['changed'] and not live_changes,(fence['changed'],live_changes)
before=json.loads((OUT/'pictures-before.json').read_text())
picture_changes=[p for p,h in before.items() if sha(ROOT/p)!=h]
concurrent_catalogues={'game/assets/garage/previews_v1/'+v+'.png' for v in ['compact','kart','forklift','electric','hovercraft']}
assert not [p for p in picture_changes if p.replace('\\','/') not in concurrent_catalogues],picture_changes
labels=['opaque-gl_compatibility','opaque-mobile','app-gl_compatibility','app-mobile','garage-gl_compatibility','garage-mobile']
receipts={label:json.loads((OUT/(label+'-command.json')).read_text()) for label in labels}
assert all(r['exit_code']==0 for r in receipts.values())
for label in ['prepared','picture-preflight','identity-before','identity-after','pictures']:
    receipts[label]=json.loads((BUILD/(label+'-command.json')).read_text())
assert all(r['exit_code']==0 and not r.get('script_errors',0) for r in receipts.values())
live_preview=subprocess.run([sys.executable,'scripts/check_garage_previews.py','--vehicles=super_rally'],cwd=ROOT,text=True,capture_output=True)
(OUT/'live-preview-check.log').write_text(live_preview.stdout+live_preview.stderr,encoding='utf-8')
assert live_preview.returncode==0,live_preview.stdout+live_preview.stderr
images={str(p.relative_to(OUT)):sha(p) for p in sorted((OUT/'garage-final').rglob('*.png'))}
receipt={'completed':True,'scope':'Challenger prepared geometry, catalogue image and desktop Garage/race',
         'observed_inputs':len(fence['after']),'bake_source_changes':fence['changed'],'live_source_changes':live_changes,
         'control_count':len(controls),'control_changes':changes,'protected_png_count':len(before),
         'protected_png_changes':picture_changes,'current_controls':controls,'commands':receipts,
         'comparison_images':images,'whole_project_or_device_qualification_claimed':False}
(OUT/'completion.json').write_text(json.dumps(receipt,indent=2))
destination=OUT/'assets';destination.mkdir(exist_ok=True)
for p in BUILD.iterdir():
    if p.is_file():shutil.copy2(p,destination/p.name)
print(json.dumps({k:v for k,v in receipt.items() if k not in ['current_controls','commands','comparison_images']}))
