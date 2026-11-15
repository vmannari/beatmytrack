from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
TAG=OUT.name;BASE='res://../docs/evidence/'+TAG+'/'
label=sys.argv[1] if len(sys.argv)>1 else 'preview'
def check(name,script,*args):
    subprocess.run([sys.executable,str(OUT/'run_check.py'),label+'-'+name,script,*args],cwd=ROOT,check=True,timeout=330)
check('native','res://tests/bake_challenger_hellcat.gd','--headless','--audio-driver','Dummy','--','--source=res://../build/'+TAG+'/converted-prototype/','--dest=res://../build/'+TAG+'/native/')
check('export',BASE+'export_meshes.gd','--headless','--audio-driver','Dummy','--','--root=res://../build/'+TAG+'/native/','--output=res://../build/'+TAG+'/candidate.json')
check('view',BASE+'capture.gd','--rendering-method','gl_compatibility','--audio-driver','Dummy','--','--candidate','--stage='+label,'--owner-only','--white-only')
