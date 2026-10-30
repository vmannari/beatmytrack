from pathlib import Path
import hashlib,json,os,shutil,subprocess

ROOT=Path.cwd();LAB=ROOT/'build/runtime-loading-fixes-2026-10-27';OUT=ROOT/'docs/evidence/runtime-loading-fixes-2026-10-27'
REVIEW=LAB/'checkpoint';BEFORE=REVIEW/'before';AFTER=REVIEW/'after';PATCH=LAB/'runtime-loading-fixes.patch'
BEFORE.mkdir(parents=True,exist_ok=True);AFTER.mkdir(parents=True,exist_ok=True)

def copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)

for source in (LAB/'task-only-after').rglob('*'):
    if not source.is_file():continue
    relative=source.relative_to(LAB/'task-only-after')
    baseline=LAB/'before'/(relative.as_posix()+'.txt')
    if baseline.exists():copy(baseline,BEFORE/relative)
    copy(source,AFTER/relative)
entry=(LAB/'status-entry.txt').read_bytes()
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    data=(LAB/'before'/(name+'.txt')).read_bytes()
    (BEFORE/name).write_bytes(data);(AFTER/name).write_bytes(data+entry)

def populate():
    for source in [ROOT/'docs/RUNTIME_LOADING_FIXES_2026_10_27.md',*OUT.rglob('*')]:
        if source.is_file():copy(source,AFTER/source.relative_to(ROOT))

def check(number):
    populate();env=os.environ.copy();env['GIT_CEILING_DIRECTORIES']=str(REVIEW)
    result=subprocess.run(['git','-c','core.autocrlf=false','-c','core.longpaths=true','diff','--no-index','--binary','--no-ext-diff','before','after'],cwd=REVIEW,env=env,capture_output=True)
    assert result.returncode==1 and result.stdout.startswith(b'diff --git '),result.stderr.decode(errors='replace')
    lines=[]
    for line in result.stdout.splitlines(keepends=True):
        if line.startswith((b'diff --git ',b'--- ',b'+++ ')):
            for a,b in [(b'a/before/',b'a/'),(b'a/after/',b'a/'),(b'b/before/',b'b/'),(b'b/after/',b'b/')]:line=line.replace(a,b)
        lines.append(line)
    PATCH.write_bytes(b''.join(lines))
    target=REVIEW/('verification-'+str(number));target.mkdir(parents=True,exist_ok=True)
    for source in BEFORE.rglob('*'):
        if source.is_file():copy(source,target/source.relative_to(BEFORE))
    discovery=subprocess.run(['git','rev-parse','--show-toplevel'],cwd=target,env=env,capture_output=True);assert discovery.returncode!=0
    for args in [['--check','--whitespace=nowarn'],['--whitespace=nowarn']]:
        applied=subprocess.run(['git','-c','core.autocrlf=false','-c','core.longpaths=true','apply',*args,str(PATCH)],cwd=target,env=env,capture_output=True)
        assert applied.returncode==0,applied.stderr.decode(errors='replace')
    expected={p.relative_to(AFTER).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in AFTER.rglob('*') if p.is_file()}
    actual={p.relative_to(target).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob('*') if p.is_file()}
    assert actual==expected
    return {'files':len(actual),'check':True,'apply':True,'byte_exact':True,'patch_bytes':PATCH.stat().st_size,'patch_sha256':hashlib.sha256(PATCH.read_bytes()).hexdigest()}

first=check(1)
receipt={'check':True,'apply':True,'byte_exact':True,'isolated':True,'root_index_used':False,
         'scope':'Only eight runtime sources, two focused tests/new UIDs, report/evidence and appended task status blocks',
         'excluded':'Concurrent App/EditorMemory regions, editor/jump/terms/model/template/native/backend work',
         'patch':'build/runtime-loading-fixes-2026-10-27/runtime-loading-fixes.patch'}
(OUT/'checkpoint-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
hashes=[]
for path in sorted(OUT.rglob('*')):
    if path.is_file() and path.name!='artifact-hashes.json':hashes.append({'path':path.relative_to(OUT).as_posix(),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'artifact-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8',newline='\n')
final=check(2)
(LAB/'checkpoint-final.json').write_text(json.dumps(final,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(final,indent=2))
