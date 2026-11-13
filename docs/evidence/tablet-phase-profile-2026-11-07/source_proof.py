import hashlib,json,shutil
from pathlib import Path
E=Path(__file__).resolve().parent;ROOT=E.parents[2];OUT=ROOT/'build/tablet-phase-profile-20261107'
base=ROOT/'build/race-verification-speed-20261107/frozen/game';current=OUT/'isolated-current/game'
extensions={'.gd','.gdshader','.gdshaderinc','.tscn','.tres','.godot','.cfg','.gdextension'}
def sources(root):
    return {p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*')
            if p.is_file() and p.suffix in extensions and not any(x in p.relative_to(root).parts for x in ['assets','.godot','android'])}
a=sources(base);b=sources(current)
changes={name:{'before':a.get(name),'after':b.get(name)} for name in sorted(set(a)|set(b)) if a.get(name)!=b.get(name)}
expected=set(json.loads((E/'instrumentation.json').read_text())['changed'])|{'core/build_identity.gd','project.godot'}
expected|={'diagnostics/tablet_phase_trace.gd','diagnostics/tablet_phase_probe.gd','diagnostics/tablet_phase_tracks.gd'}
assert set(changes)==expected,set(changes)^expected
digest=lambda value:hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()
receipt={'baseline':'0.3.0-creator.e14bec0e820302b39bbb8c16684bda60','profile':'0.3.0-creator.5461f09de97da8ac7b795c7d097e3912',
         'scope':'game source/resource declarations outside assets/imported/Android-generated directories; UID sidecars excluded',
         'baseline_files':len(a),'profile_files':len(b),'baseline_aggregate_sha256':digest(a),'profile_aggregate_sha256':digest(b),
         'changes_exactly_declared':True,'changes':changes}
(OUT/'source-proof-full.json').write_text(json.dumps({'baseline':a,'profile':b},indent=2)+'\n')
(E/'source-proof.json').write_text(json.dumps(receipt,indent=2)+'\n')
if (E/'frozen-project.json').exists():
    shutil.move(str(E/'frozen-project.json'),str(E/'superseded-7694/initial-frozen-project.json'))
print(json.dumps({k:v for k,v in receipt.items() if k!='changes'}))
