from pathlib import Path
import subprocess,sys,json,time
root=Path.cwd();out=Path(__file__).resolve().parent;b=root/'build'/out.name
blender=str(root/'build/tools/blender-4.5.15-windows-x64/blender.exe')
def run(script,label,args=[]):
 command=[blender,'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(out/script),*args]
 with (out/(label+'.log')).open('w') as log:
  subprocess.run(command,check=True,stdout=log,stderr=subprocess.STDOUT)
 print(label,'passed',flush=True)
started=time.time()
run('prototype.py','qualified-prototype')
assert (b/'prototype.json').stat().st_mtime>=started
base=json.loads((b/'baseline.json').read_text());data=json.loads((b/'prototype.json').read_text())
for tier in base:base[tier].update(data[tier])
(b/'prototype-all.json').write_text(json.dumps(base,separators=(',',':')))
run('check_seams_corners.py','qualified-prototype-crown',['--','prototype-all'])
run('check_leading_surface.py','qualified-prototype-leading',['--','prototype-all'])
