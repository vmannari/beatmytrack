"""Reviewable source-only checkpoint; no writes to the shared Git index."""
from pathlib import Path
import difflib,hashlib,json,subprocess

ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-panel-corrections-2026-11-14'
FILES=['scripts/prepare_challenger.py','game/tests/bake_challenger_hellcat.gd',
       'scripts/challenger_clean_panels.py','game/vehicle/challenger_panel_contours.gd','game/vehicle/car_mesh_lods.gd','game/tests/test_panel_contours.gd','docs/CHALLENGER_PANEL_CORRECTIONS_2026_11_14.md','AGENTS.md']
FILES += sorted(p.relative_to(ROOT).as_posix() for p in OUT.iterdir()
                if p.is_file() and (p.suffix in ['.py','.ps1','.gd','.uid'] or p.name=='agents-entry.txt'))
sha=lambda b:hashlib.sha256(b).hexdigest()
index_before=sha((ROOT/'.git/index').read_bytes())
before={};after={};patch=''
for name in FILES:
    after[name]=(ROOT/name).read_bytes()
    baseline=OUT/'before'/name
    before[name]=baseline.read_bytes() if baseline.exists() else None
    if name=='AGENTS.md':
        block=(OUT/'agents-entry.txt').read_text().rstrip('\n').encode()+b'\n\n'
        assert after[name].count(block)==1
        before[name]=after[name].replace(block,b'',1)
    patch+=''.join(difflib.unified_diff((before[name] or b'').decode().splitlines(True),
                                      after[name].decode().splitlines(True),
                                      'a/'+name if before[name] is not None else '/dev/null','b/'+name))
patch_path=OUT/'source-only.patch';patch_path.write_bytes(patch.encode())
check=BUILD/'source-checkpoint';check.mkdir(exist_ok=True)
assert check.resolve().is_relative_to(BUILD.resolve())
for name in FILES:
    p=check/name;p.parent.mkdir(parents=True,exist_ok=True)
    if before[name] is not None:p.write_bytes(before[name])
    elif p.exists():p.unlink()
def run(*args):
    result=subprocess.run(['git','-C',str(check),*args],capture_output=True,text=True)
    if result.returncode:raise RuntimeError(result.stdout+result.stderr)
run('init','--quiet')
run('config','core.autocrlf','false')
run('config','core.whitespace','blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol')
run('apply','--whitespace=error',str(patch_path))
assert all((check/n).read_bytes()==after[n] for n in FILES)
run('apply','--reverse','--whitespace=error',str(patch_path))
assert all((check/n).read_bytes()==before[n] if before[n] is not None else not (check/n).exists() for n in FILES)
index_after=sha((ROOT/'.git/index').read_bytes())
receipt={'forward_byte_exact':True,'reverse_byte_exact':True,'whitespace_clean':True,
         'main_index_written':False,'index_unchanged_during_checkpoint':index_before==index_after,
         'index_before':index_before,'index_after':index_after,'patch_sha256':sha(patch_path.read_bytes()),
         'agents_baseline':'Current shared AGENTS with only this task block removed; concurrent entries retained.',
         'files':{n:{'before_sha256':sha(before[n]) if before[n] is not None else None,'sha256':sha(after[n])} for n in FILES}}
(OUT/'source-checkpoint.json').write_text(json.dumps(receipt,indent=2))
print('SOURCE_CHECKPOINT:',len(FILES),'files; byte-exact forward/reverse; whitespace clean; shared index unchanged',index_before==index_after)
