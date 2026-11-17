from pathlib import Path
import subprocess,sys,json
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
base='res://../docs/evidence/'+out.name+'/'
def check(label,script,*args):
 subprocess.run([sys.executable,str(out/'run_check.py'),label,script,'--headless','--audio-driver','Dummy',*args],cwd=root,check=True)
check('native-bake','res://tests/bake_challenger_hellcat.gd','--','--source=res://../build/'+out.name+'/converted/','--dest=res://../build/'+out.name+'/native/')
check('candidate-export',base+'export_meshes.gd','--','--root=res://../build/'+out.name+'/native/','--output=res://../build/'+out.name+'/candidate.json')
with (out/'candidate-rear.log').open('w') as log:
 subprocess.run([str(root/'build/tools/blender-4.5.15-windows-x64/blender.exe'),'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(out/'check_rear.py'),'--','candidate'],cwd=root,check=True,stdout=log,stderr=subprocess.STDOUT)
r=json.loads((out/'candidate-rear.json').read_text())
print('REAR_NATIVE',r['checks'],r['failures'],r['metrics'],flush=True)
check('candidate-trunk',base+'check_trunk.gd')
check('allocation',base+'allocation.gd')
check('candidate-contours',base+'contours_candidate.gd')
