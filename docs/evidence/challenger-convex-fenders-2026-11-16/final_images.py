from pathlib import Path
import subprocess,sys,json
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
before=json.loads((OUT/'post-import-identity.json').read_text())
(OUT/'initial-post-import-identity.json').write_text(json.dumps(before,indent=2))
def run(*args):subprocess.run(args,cwd=ROOT,check=True,timeout=360)
def check(label,script,*extra):run(sys.executable,str(OUT/'run_check.py'),label,script,*extra,'--audio-driver','Dummy')
check('final-header','res://tests/bake_header_simple_compact.gd','--headless')
run(sys.executable,str(OUT/'import_images.py'))
run(sys.executable,str(OUT/'post_import_identity.py'))
check('final-portraits','res://tests/bake_garage_selection_portraits.gd','--rendering-method','gl_compatibility')
run(sys.executable,str(OUT/'import_images.py'))
run(sys.executable,'scripts/check_garage_selection_pictures.py')
(OUT/'final-images.json').write_text(json.dumps({'actual_header_and_portrait_rebuild':True,'imports_verified':True,'selection_picture_preflight_passed':True},indent=2))
