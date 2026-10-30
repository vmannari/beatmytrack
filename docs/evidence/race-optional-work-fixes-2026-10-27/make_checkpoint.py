from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import time

ROOT=Path.cwd()
LAB=ROOT/'build/race-optional-work-fixes-2026-10-27'
OUT=ROOT/'docs/evidence/race-optional-work-fixes-2026-10-27'
REVIEW=LAB/'checkpoint'
BEFORE=REVIEW/'before'
AFTER=REVIEW/'after'
PATCH=LAB/'task-only.patch'
RUN_ID=str(time.time_ns())
BEFORE.mkdir(parents=True,exist_ok=True)
AFTER.mkdir(parents=True,exist_ok=True)


def copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)


for row in json.loads((LAB/'before.json').read_text(encoding='utf-8'))['files']:
    name=row['path']
    copy(LAB/'before'/name,BEFORE/name)
    copy(LAB/'task-after'/name,AFTER/name)
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    data=(LAB/'status-before'/name).read_bytes()
    current=(ROOT/name).read_bytes()
    marker=b'<!-- RACE-OPTIONAL-WORK-FIXES-20261027 -->'
    end_marker=b'<!-- /RACE-OPTIONAL-WORK-FIXES-20261027 -->'
    start=current.index(marker)
    end=current.index(end_marker,start)+len(end_marker)
    (BEFORE/name).write_bytes(data)
    (AFTER/name).write_bytes(data+b'\n\n'+current[start:end]+b'\n')


def populate():
    for name in ['game/tests/test_race_optional_work.gd','game/tests/test_race_optional_work.gd.uid','docs/RACE_OPTIONAL_WORK_FIXES_2026_10_27.md']:
        if (ROOT/name).exists():copy(ROOT/name,AFTER/name)
    for source in OUT.rglob('*'):
        if source.is_file():copy(source,AFTER/source.relative_to(ROOT))


def verify(number):
    populate()
    env=os.environ.copy()
    env['GIT_CEILING_DIRECTORIES']=str(REVIEW)
    result=subprocess.run(['git','-c','core.autocrlf=false','diff','--no-index','--binary','--no-ext-diff','before','after'],cwd=REVIEW,env=env,capture_output=True)
    assert result.returncode==1,result.stderr.decode(errors='replace')
    lines=[]
    for line in result.stdout.splitlines(keepends=True):
        if line.startswith((b'diff --git ',b'--- ',b'+++ ')):
            for old,new in [(b'a/before/',b'a/'),(b'a/after/',b'a/'),(b'b/before/',b'b/'),(b'b/after/',b'b/')]:line=line.replace(old,new)
        lines.append(line)
    PATCH.write_bytes(b''.join(lines))
    target=REVIEW/('verification-'+RUN_ID+'-'+str(number))
    target.mkdir(parents=True,exist_ok=True)
    for source in BEFORE.rglob('*'):
        if source.is_file():copy(source,target/source.relative_to(BEFORE))
    discover=subprocess.run(['git','rev-parse','--show-toplevel'],cwd=target,env=env,capture_output=True)
    assert discover.returncode!=0,'Verification cannot discover owner repository'
    for arguments in [['--check','--whitespace=nowarn'],['--whitespace=nowarn']]:
        applied=subprocess.run(['git','-c','core.autocrlf=false','apply',*arguments,str(PATCH)],cwd=target,env=env,capture_output=True)
        assert applied.returncode==0,applied.stderr.decode(errors='replace')
    expected={p.relative_to(AFTER).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in AFTER.rglob('*') if p.is_file()}
    actual={p.relative_to(target).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob('*') if p.is_file()}
    assert actual==expected
    return dict(check=True,apply=True,byte_exact=True,files=len(actual),patch_sha256=hashlib.sha256(PATCH.read_bytes()).hexdigest(),patch_bytes=PATCH.stat().st_size)


verify(1)
receipt=dict(check=True,apply=True,byte_exact=True,isolated=True,root_index_used=False,
             scope='Five task-only runtime deltas, new focused test/UID, task documentation/evidence and appended status blocks',
             excluded='Concurrent App road-material controls/helper, rendering/cache, upload-rounding/backend and other pre-existing changes',
             patch='build/race-optional-work-fixes-2026-10-27/task-only.patch')
(OUT/'checkpoint-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
hashes=[]
for p in sorted(OUT.rglob('*')):
    if p.is_file() and p.name!='artifact-hashes.json':
        data=p.read_bytes()
        hashes.append(dict(path=p.relative_to(OUT).as_posix(),bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
(OUT/'artifact-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8',newline='\n')
result=verify(2)
(LAB/'checkpoint-final.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(result,indent=2))
