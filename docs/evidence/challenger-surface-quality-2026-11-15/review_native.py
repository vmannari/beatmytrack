"""Decode and review the converter's real packed Godot output."""
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
TAG = OUT.name
BASE = 'res://../docs/evidence/'+TAG+'/'
def run(*args):
    subprocess.run(args,cwd=ROOT,check=True,timeout=360)
def check(label, script, *args):
    run(sys.executable,str(OUT/'run_check.py'),label,script,'--headless','--audio-driver','Dummy',*args)
check('native-bake','res://tests/bake_challenger_hellcat.gd','--','--source=res://../build/'+TAG+'/converted/','--dest=res://../build/'+TAG+'/native/')
check('candidate-export',BASE+'export_meshes.gd','--','--root=res://../build/'+TAG+'/native/','--output=res://../build/'+TAG+'/candidate.json')
for script in ['diagnose.py','check_quality.py']:
    run(str(ROOT/'build/tools/blender-4.5.15-windows-x64/blender.exe'),'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(OUT/script),'--','candidate')
check('allocation',BASE+'allocation.gd')
check('candidate-contours',BASE+'contours_candidate.gd')
run(sys.executable,str(OUT/'run_check.py'),'candidate-gl',BASE+'capture.gd','--rendering-method','gl_compatibility','--audio-driver','Dummy','--','--candidate','--stage=candidate','--marked-only')
