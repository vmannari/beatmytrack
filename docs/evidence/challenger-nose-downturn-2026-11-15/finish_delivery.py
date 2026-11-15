"""Close post-import identity and existing-source qualification."""
from pathlib import Path
import json,subprocess,sys,re
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;ASSETS=ROOT/'build'/OUT.name/'assets'
def run(*args):subprocess.run(args,cwd=ROOT,check=True,timeout=900)
run('powershell','-NoProfile','-ExecutionPolicy','Bypass','-Command',". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path 'build/"+OUT.name+"/assets'")
identity=json.loads((ASSETS/'client-build-identity.json').read_text(encoding='utf-8-sig'))
previous=json.loads((ASSETS/'identity-before.json').read_text())
assert identity['modular_car_sha256']==previous['modular_car_sha256']
(OUT/'post-import-identity.json').write_text(json.dumps({'model_keys_unchanged':True,'header_revision_unchanged':identity['header_preview_sha256']==previous['header_preview_sha256'],'header_revision':identity['header_preview_sha256'],'garage_revision':identity['garage_preview_sha256'],'prior_garage_revision':previous['garage_preview_sha256'],'actual_portrait_rebake_required':True},indent=2))
def check(label,script,*args,native=False):
    run(sys.executable,str(OUT/'run_check.py'),label,script,*(['--rendering-method','gl_compatibility'] if native else ['--headless']),'--audio-driver','Dummy',*args)
check('portraits','res://tests/bake_garage_selection_portraits.gd',native=True)
run(sys.executable,str(OUT/'import_images.py'))
check('live-contours','res://tests/test_panel_contours.gd')
check('prepared-complete','res://tests/check_prepared_assets.gd')
run(sys.executable,str(OUT/'gpu_checks.py'))
run(sys.executable,'scripts/check_garage_selection_pictures.py')
run(sys.executable,'scripts/check_garage_previews.py','--vehicles=super_rally')
run(sys.executable,'scripts/check_garage_workshop.py')
print('NOSE_DELIVERY_FINAL checks, final identity and genuine portrait rebake complete.')
