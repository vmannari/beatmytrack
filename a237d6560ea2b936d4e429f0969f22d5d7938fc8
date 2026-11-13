"""Task-only code delta, exact shared controls and separately pinned source art."""
from pathlib import Path
import difflib,hashlib,json,os,shutil,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
owned=['scripts/prepare_challenger.py','scripts/challenger_panel_geometry.py',
       'scripts/challenger_detail_geometry.py','game/tests/bake_challenger_hellcat.gd',
       'game/vehicle/super_rally_model.gd','game/legal/challenger_hellcat_notices.txt']
delta=[]
for name in owned:
    before=OUT/'before'/name;after=ROOT/name
    delta.append(('diff --git a/'+name+' b/'+name+'\n').encode())
    if not before.exists():delta.append(b'new file mode 100644\n')
    old=before.read_bytes().splitlines(keepends=True) if before.exists() else []
    new=after.read_bytes().splitlines(keepends=True)
    for line in difflib.diff_bytes(difflib.unified_diff,old,new,
            fromfile=('a/'+name if before.exists() else '/dev/null').encode(),tofile=('b/'+name).encode()):
        delta.append(line if line.endswith(b'\n') else line+b'\n\\ No newline at end of file\n')
patch=OUT/'source-only.patch';patch.write_bytes(b''.join(delta))
env={**os.environ,'GIT_OPTIONAL_LOCKS':'0'}
def git(*args):
    result=subprocess.run(['git','apply','--whitespace=nowarn',*args,str(patch.relative_to(ROOT))],cwd=ROOT,env=env,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
git('--check','--reverse')
private=ROOT/'build/challenger-panels-checkpoint'
for name in owned:
    target=private/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
prefix='--directory='+private.relative_to(ROOT).as_posix()
git(prefix,'--check','--reverse');git(prefix,'--reverse')
for name in owned:
    before=OUT/'before'/name;target=private/name
    assert target.read_bytes()==before.read_bytes() if before.exists() else not target.exists(),name
git(prefix,'--check');git(prefix)
assert all((private/n).read_bytes()==(ROOT/n).read_bytes() for n in owned)
initial=json.loads((OUT/'start-sources.json').read_text())
controls={n:{'before':h,'after':sha(ROOT/n)} for n,h in initial.items()
          if n not in owned and not n.startswith('game/assets/vehicles/')}
exact={n:v for n,v in controls.items() if v['before']==v['after']}
concurrent={n:v for n,v in controls.items() if v['before']!=v['after']}
native={p.relative_to(ROOT).as_posix():{'sha256':sha(p),'bytes':p.stat().st_size}
        for p in (ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*') if p.suffix in ['.res','.json']}
art={p.relative_to(ROOT).as_posix():{'sha256':sha(p),'bytes':p.stat().st_size}
     for p in (ROOT/'art_sources/challenger_hellcat_v1').glob('*') if p.is_file()}
receipt={'authored_sources':{n:sha(ROOT/n) for n in owned},'exact_controls':exact,
 'preserved_concurrent_sources':concurrent,'native_assets':native,'retained_source_art':art,
 'original_download_removed_by_owner':True,'original_download_exists':Path(r'C:\Users\ville\Downloads\Dodge Challenger HellCat - Rigged.blend').exists(),
 'source_only_patch':{'sha256':sha(patch),'files':len(owned),'reverse_check':0,'private_reverse_byte_exact':True,'private_forward_byte_exact':True,
 'excludes':'Generated resources, source-art binaries/metadata (pinned separately), documentation, evidence and concurrent work.'}}
(OUT/'source-receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('CHALLENGER_PANEL_CHECKPOINT:',len(owned),'sources;',len(exact),'exact controls;',len(concurrent),'preserved concurrent sources;',len(native),'native resources; both byte-exact directions pass')
