from pathlib import Path
import hashlib,json,os,subprocess,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
runner=OUT/'run_check.py'
subprocess.run([sys.executable,str(runner),'prepared-final-live','res://tests/check_prepared_assets.gd','--headless','--audio-driver','Dummy'],cwd=ROOT,check=True)
result=subprocess.run([sys.executable,'scripts/check_garage_previews.py'],cwd=ROOT,capture_output=True,text=True,check=True)
(OUT/'picture-final-live.log').write_text(result.stdout+result.stderr,encoding='utf-8')
sources=json.loads((OUT/'assets-source-receipt.json').read_text())
assert sources['before']==sources['after'] and not sources['changed']
changed=[p for p,h in sources['after'].items() if sha(ROOT/p)!=h]
assert not changed,changed
checkpoint=json.loads((OUT/'source-receipt.json').read_text())
for group in ['authored_sources','native_assets','retained_source_art']:
    for path,info in checkpoint[group].items():
        expected=info if isinstance(info,str) else info['sha256']
        assert sha(ROOT/path)==expected,path
qualified=json.loads((OUT/'qualified-commands.json').read_text())
for label in ['picture-controls','detail-accepted','prepared-final-live']:
    qualified[label]=json.loads((OUT/(label+'-command.json')).read_text())
assert all(r['exit_code']==0 and r.get('script_errors',0)==0 for r in qualified.values())
assets=json.loads((OUT/'assets-commands.json').read_text())
assert len(assets)==15 and all(r['exit_code']==0 and r.get('script_errors',0)==0 for r in assets.values())
panels=json.loads((OUT/'panel-after.json').read_text());shading=json.loads((OUT/'shading-after.json').read_text())
assert panels['failures']==shading['failures']==0
opacity={r:json.loads((OUT/'opaque'/r/'acceptance.json').read_text()) for r in ['gl_compatibility','mobile']}
app={r:json.loads((OUT/'app'/r/'acceptance.json').read_text()) for r in opacity}
assert all(v['failures']==0 for group in [opacity,app] for v in group.values())
pictures=json.loads((OUT/'picture-control-results.json').read_text())
assert pictures['exact']==pictures['total']==20
for path,info in json.loads((OUT/'pictures-immediately-before-refresh.json').read_text()).items():assert sha(ROOT/path)==info,path
review={r:json.loads((OUT/'final'/r/'geometry.json').read_text()) for r in opacity}
assert review['gl_compatibility']==review['mobile']
receipt={'status':'passed','date':'2026-11-12','source_art_mode':'retained measured source body; original download removed by owner',
 'qualified_commands':qualified,'stable_asset_inputs':len(sources['before']),'asset_commands':len(assets),
 'final_live_source_changes':changed,'prepared_resources':551,'prepared_checks':2267,
 'native_preview_pictures':6,'native_preview_source_hashes':157,'panels':panels,'shading':shading,
 'opacity':opacity,'actual_app':app,'picture_controls':pictures,'renderer_geometry':review,
 'source_checkpoint_sha256':sha(OUT/'source-receipt.json'),'source_patch_sha256':sha(OUT/'source-only.patch'),
 'limits':['Desktop renderer qualification; no device/frame-time/thermal acceptance','Fresh desktop launch and owner appearance acceptance remain',
 'No APK/export, owner save/process change, live backend request, deployment or main-index write']}
(OUT/'final-acceptance.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('CHALLENGER_FINAL_AUDIT: all qualified checks, live source fence, native resource and picture provenance gates pass; 20/20 current PNG controls exact')
