from pathlib import Path
import difflib,hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files=['scripts/prepare_challenger.py','scripts/challenger_panel_geometry.py']
patch=''
for name in files:
    before=(OUT/'before'/Path(name).name).read_bytes().decode('utf-8')
    after=(ROOT/name).read_bytes().decode('utf-8')
    patch+=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),'a/'+name,'b/'+name))
(OUT/'source-only.patch').write_bytes(patch.encode('utf-8'))
check=ROOT/'build/challenger-surface-joins-2026-11-12/source-checkpoint'
check.mkdir(parents=True,exist_ok=True)
for name in files:
    target=check/name;target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes((OUT/'before'/Path(name).name).read_bytes())
subprocess.run(['git','init','--quiet',str(check)],check=True)
command=['git','-C',str(check),'apply','--whitespace=error',str(OUT/'source-only.patch')]
subprocess.run(command,check=True)
assert all((check/p).read_bytes()==(ROOT/p).read_bytes() for p in files)
subprocess.run(command[:4]+['--reverse']+command[4:],check=True)
assert all((check/p).read_bytes()==(OUT/'before'/Path(p).name).read_bytes() for p in files)
(OUT/'source-checkpoint.json').write_text(json.dumps({'files':{p:{'before':sha(OUT/'before'/Path(p).name),'after':sha(ROOT/p)} for p in files},'forward_exact':True,'reverse_exact':True,'whitespace_clean':True},indent=2))
print('Two-source checkpoint applies and reverses byte-exactly')
