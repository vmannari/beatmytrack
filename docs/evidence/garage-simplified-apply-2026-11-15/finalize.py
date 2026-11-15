from pathlib import Path
import sys,subprocess,json,re,shutil
r=Path.cwd();w=r/'build/garage-simplified-apply-2026-11-15'
def revisions(p):return json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',p.read_text())[1])
original=revisions(w/'before/build_identity.gd')
def step(name,args):
 p=subprocess.run(args,capture_output=True,text=True)
 (w/(name+'-launcher.log')).write_text(p.stdout+p.stderr,encoding='utf-8')
 print(name,p.returncode,flush=True)
 if p.returncode: print(p.stdout[-3000:]+p.stderr[-3000:]);raise SystemExit(p.returncode)
step('identity-initial',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(w/'refresh_identity.ps1')])
assert revisions(r/'game/core/build_identity.gd')==original,'Unexpected modular car revision change'
step('publish-catalogue',[sys.executable,'scripts/run_garage_simplified.py','publish-catalogue','--script','res://../scripts/bake_garage_previews.gd','--output=res://assets/garage/previews_v1'])
step('identity-pictures',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(w/'refresh_identity.ps1')])
assert revisions(r/'game/core/build_identity.gd')==original
step('publish-portraits',[sys.executable,'scripts/run_garage_simplified.py','publish-portraits','--script','res://tests/bake_garage_selection_portraits.gd'])
# Import only these twelve accepted PNGs in a private editor project.
sys.path.insert(0,str(r/'scripts'))
import import_garage_fast_entry_images as imports
source=Path(imports.__file__).read_text().replace('assert len(images) == 6',"images += [ROOT / 'game/assets/garage/selection_portraits_v1' / p.name for p in images]\n    assert len(images) == 12")
module={"__name__":"private_import","__file__":str(r/'scripts/import_garage_fast_entry_images.py')};exec(compile(source,'private_import','exec'),module)
module['WORK']=w/'image-import';module['PROJECT']=module['WORK']/'game';module['main']()
step('identity-final',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(w/'refresh_identity.ps1')])
assert revisions(r/'game/core/build_identity.gd')==original
for name in ['check_garage_workshop.py','check_garage_previews.py','check_garage_selection_pictures.py']:
 step(name,[sys.executable,'scripts/'+name])
print('All original modular car keys remain exact',flush=True)
