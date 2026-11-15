from pathlib import Path
import subprocess,sys,json,re,hashlib
r=Path.cwd();w=r/'build/garage-speakers-fix-2026-11-15'
rev=lambda p:json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',p.read_text())[1])
original=rev(w/'before/build_identity.gd')
def step(name,args):
 p=subprocess.run(args,capture_output=True,text=True)
 (w/(name+'-launcher.log')).write_text(p.stdout+p.stderr,encoding='utf-8');print(name,p.returncode,flush=True)
 if p.returncode: print(p.stdout[-2000:]+p.stderr[-2000:]);raise SystemExit(p.returncode)
def identity(name):
 step(name,['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(w/'refresh_identity.ps1'),'-Receipt',name])
 assert rev(r/'game/core/build_identity.gd')==original,'Car geometry revision changed outside speaker scope'
def probe(name,script,renderer='gl_compatibility',options=[]):
 step(name,[sys.executable,'scripts/run_garage_speakers.py',name,'--script',script,'--renderer',renderer,*options])
def images(portraits=False):
 sys.path.insert(0,str(r/'scripts'));import import_garage_fast_entry_images as imports
 source=Path(imports.__file__).read_text()
 if portraits:source=source.replace('game/assets/garage/previews_v1','game/assets/garage/selection_portraits_v1')
 module={'__name__':'private_import','__file__':str(r/'scripts/import_garage_fast_entry_images.py')};exec(compile(source,'private_import','exec'),module)
 name='portrait-import' if portraits else 'catalogue-import';module['WORK']=w/name;module['PROJECT']=module['WORK']/'game';module['main']()
identity('identity-source')
probe('catalogue','res://../scripts/bake_garage_previews.gd',options=['--output=res://assets/garage/previews_v1'])
images()
identity('identity-catalogue')
probe('portraits','res://tests/bake_garage_selection_portraits.gd')
images(True)
identity('identity-final')
for checker in ['check_garage_workshop.py','check_garage_previews.py','check_garage_selection_pictures.py']:
 step(checker,[sys.executable,'scripts/'+checker])
for renderer,label in [('gl_compatibility','gl'),('mobile','mobile')]:
 probe('speakers-'+label,'res://tests/test_garage_speakers.gd',renderer)
 probe('native-'+label+'-final','res://../build/garage-speakers-fix-2026-11-15/capture.gd',renderer)
 probe('receiving-'+label,'res://tests/test_garage_first_capture.gd',renderer)
 probe('motion-'+label,'res://tests/test_garage_reflections.gd',renderer,['--capture-motion-output='+str(w/('motion-'+label))])
print('Speaker restoration and native entry complete',flush=True)
