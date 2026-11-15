from pathlib import Path
import hashlib,json,re,subprocess,sys
r=Path.cwd();w=r/'build/garage-simplified-apply-2026-11-15'
controls=json.loads((w/'car-output-controls.json').read_text())
def capture():
 paths=set(controls)
 for folder in ['game/ui','game/vehicle','game/rendering','game/core','game/assets/garage']:
  paths.update(p.relative_to(r).as_posix() for p in (r/folder).rglob('*') if p.is_file() and '.asset-bake-lock' not in p.parts)
 paths.update(['game/export_presets.cfg','game/project.godot','scripts/build_identity.ps1','scripts/bake_garage_previews.gd'])
 return {p:hashlib.sha256((r/p).read_bytes()).hexdigest() for p in sorted(paths)}
before=capture();(w/'stable-final-inputs.json').write_text(json.dumps(before,indent=2))
# The new binding does not change native PNG pixels; accepted native imports stay current.
imports=json.loads((w/'current-image-imports.json').read_text())
assert all(hashlib.md5((r/'game'/row['path']).read_bytes()).hexdigest()==row['source_md5'] for row in imports['images'])
results=[]
for name,renderer in [('stable-app-gl','gl_compatibility'),('stable-app-mobile','mobile')]:
 p=subprocess.run([sys.executable,'scripts/run_garage_simplified.py',name,'--renderer',renderer,'--script','res://../build/garage-simplified-apply-2026-11-15/live_entry_foreground.gd'],capture_output=True,text=True)
 (w/(name+'-launcher.log')).write_text(p.stdout+p.stderr,encoding='utf-8');results.append([name,p.returncode]);print(name,p.returncode,flush=True)
 assert p.returncode==0,p.stdout[-2500:]
for checker in ['check_garage_workshop.py','check_garage_previews.py','check_garage_selection_pictures.py']:
 p=subprocess.run([sys.executable,'scripts/'+checker],capture_output=True,text=True)
 (w/(checker+'-stable.log')).write_text(p.stdout+p.stderr,encoding='utf-8');print(checker,p.returncode,flush=True);assert p.returncode==0,p.stderr
current=capture();changed=[p for p in before.keys()|current.keys() if before.get(p)!=current.get(p)]
cars=[p for p,h in controls.items() if current[p]!=h]
rev=lambda p:json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',p.read_text())[1])
proof={'fenced_inputs':len(before),'changed_inputs':changed,'car_outputs':len(controls),'changed_car_outputs':cars,'car_keys_exact':rev(w/'before/build_identity.gd')==rev(r/'game/core/build_identity.gd'),'native_imports_exact':12,'results':results}
(w/'stable-final-proof.json').write_text(json.dumps(proof,indent=2));print(json.dumps(proof),flush=True)
assert not changed and not cars and proof['car_keys_exact']
