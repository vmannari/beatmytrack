"""Task-only binary patch, exercised in a separate temporary Git repository."""
from pathlib import Path
import hashlib, json, shutil, subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

def baseline(name):
    scoped=OUT/'checkpoint-base'/name
    return scoped if scoped.is_file() else OUT/'before'/name

def main():
    index_before=digest(ROOT/'.git/index')
    candidates=set(json.loads((OUT/'before-hashes.json').read_text()))
    candidates.update(['game/tests/capture_forklift_kit_refinement.gd',
        'game/tests/test_forklift_cover_decks.gd','scripts/run_forklift_cover_guard.ps1',
        'docs/FORKLIFT_COVER_GUARD_VARIATION_2026_11_03.md','AGENTS.md','DEVELOPMENT_STATUS.md',
        'docs/evidence/forklift-cover-guard-variation-2026-11-03/before/game/vehicle/forklift_kit_surface.gd'])
    # Documentation includes only this task's new marker; all other notes remain in baseline.
    for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
        data=(ROOT/name).read_bytes()
        start=data.index(b'<!-- FORKLIFT-COVER-GUARD-VARIATION-20261103 -->')
        end=data.index(b'<!-- /FORKLIFT-COVER-GUARD-VARIATION-20261103 -->',start)+len(b'<!-- /FORKLIFT-COVER-GUARD-VARIATION-20261103 -->')
        while data[end:end+1] in [b'\r',b'\n']: end+=1
        target=OUT/'checkpoint-base'/name
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data[:start]+data[end:])
    changed=sorted(n for n in candidates if digest(baseline(n))!=digest(ROOT/n))
    work=ROOT/'tmp/forklift-cover-guard-variation-checkpoint'
    work.mkdir(parents=True,exist_ok=False)
    def git(*args):
        return subprocess.run(['git','-c','core.autocrlf=false',*args],cwd=work,capture_output=True,check=True).stdout
    git('init','-q')
    for name in changed:
        if baseline(name).is_file():
            target=work/name
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(baseline(name),target)
    git('add','.')
    git('-c','user.name=Codex','-c','user.email=codex@local.invalid','commit','-qm','Cover and guard task-start baseline')
    for name in changed:
        target=work/name
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/name,target)
    git('add','.')
    patch=git('diff','--cached','--binary','HEAD')
    (OUT/'task.patch').write_bytes(patch)
    git('apply','--reverse','--check',str(OUT/'task.patch'))
    git('apply','--reverse',str(OUT/'task.patch'))
    assert all(digest(work/n)==digest(baseline(n)) for n in changed)
    git('apply','--check',str(OUT/'task.patch'))
    git('apply',str(OUT/'task.patch'))
    assert all(digest(work/n)==digest(ROOT/n) for n in changed)
    assert index_before==digest(ROOT/'.git/index')
    result={'files':changed,'patch_bytes':len(patch),'sha256':hashlib.sha256(patch).hexdigest(),
        'reverse_check':True,'reverse_content':True,'forward_check':True,'forward_content':True,
        'root_index_written':False,'root_index_sha256':index_before,'generated_build_identity_excluded':True}
    (OUT/'checkpoint.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(f'Checkpoint round trip: {len(changed)} files, {len(patch)} bytes, root index unchanged')

if __name__=='__main__': main()
