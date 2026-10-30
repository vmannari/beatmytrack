from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

ROOT = Path.cwd()
LAB = ROOT/'build/re-audit-2026-10-27'
OUT = ROOT/'docs/evidence/mobile-reaudit-2026-10-27'
REVIEW = LAB/'checkpoint'
BEFORE = REVIEW/'before'
AFTER = REVIEW/'after'
PATCH = LAB/'audit-only.patch'
for folder in [BEFORE, AFTER]:
    folder.mkdir(parents=True, exist_ok=True)

# Reconstruct exactly our appended status slice against its saved baseline,
# excluding any other author's changes made after the baseline was read.
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md']:
    baseline = (LAB/'checkpoint-before'/name).read_bytes()
    current = (ROOT/name).read_bytes()
    marker = b'<!-- MOBILE-REAUDIT-20261027 -->'
    end_marker = b'<!-- /MOBILE-REAUDIT-20261027 -->'
    start = current.index(marker)
    end = current.index(end_marker, start)+len(end_marker)
    block = b'\n\n'+current[start:end]+b'\n'
    (BEFORE/name).write_bytes(baseline)
    (AFTER/name).write_bytes(baseline+block)


def populate_documents():
    for source in [ROOT/'docs/COMPREHENSIVE_MOBILE_REAUDIT_2026_10_27.md', *OUT.rglob('*')]:
        if not source.is_file():
            continue
        target=AFTER/source.relative_to(ROOT)
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,target)


def make_and_verify(number):
    populate_documents()
    env=os.environ.copy()
    env['GIT_CEILING_DIRECTORIES']=str(REVIEW)
    result=subprocess.run(['git','-c','core.autocrlf=false','diff','--no-index','--binary','--no-ext-diff','before','after'],cwd=REVIEW,env=env,capture_output=True)
    assert result.returncode==1,(result.returncode,result.stderr.decode(errors='replace'))
    output=[]
    for line in result.stdout.splitlines(keepends=True):
        if line.startswith((b'diff --git ',b'--- ',b'+++ ')):
            for old,new in [(b'a/before/',b'a/'),(b'a/after/',b'a/'),(b'b/before/',b'b/'),(b'b/after/',b'b/')]:
                line=line.replace(old,new)
        output.append(line)
    PATCH.write_bytes(b''.join(output))
    verification=REVIEW/('verification-'+str(number))
    verification.mkdir(parents=True,exist_ok=True)
    for source in BEFORE.rglob('*'):
        if source.is_file():
            target=verification/source.relative_to(BEFORE)
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,target)
    discovery=subprocess.run(['git','rev-parse','--show-toplevel'],cwd=verification,env=env,capture_output=True)
    assert discovery.returncode!=0,'Verification must not discover the owner repository'
    commands=[]
    for args in [['--check','--whitespace=nowarn'],['--whitespace=nowarn']]:
        command=['git','-c','core.autocrlf=false','apply',*args,str(PATCH)]
        checked=subprocess.run(command,cwd=verification,env=env,capture_output=True)
        assert checked.returncode==0,checked.stderr.decode(errors='replace')
        commands.append(command)
    expected={path.relative_to(AFTER).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in AFTER.rglob('*') if path.is_file()}
    actual={path.relative_to(verification).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in verification.rglob('*') if path.is_file()}
    assert actual==expected
    return dict(files=len(actual),check=True,apply=True,byte_exact=True,commands=commands,patch_sha256=hashlib.sha256(PATCH.read_bytes()).hexdigest(),patch_bytes=PATCH.stat().st_size)


first=make_and_verify(1)
receipt=dict(check=True,apply=True,byte_exact=True,scope='Audit document, audit evidence, and only the appended audit status blocks in AGENTS.md and DEVELOPMENT_STATUS.md',
             patch='build/re-audit-2026-10-27/audit-only.patch',
             isolated=True,root_git_index_used=False,
             excluded='All game/backend/native changes, including concurrent edits and incidental generated build metadata')
(OUT/'checkpoint-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
hashes=[]
for path in sorted(OUT.rglob('*')):
    if path.is_file() and path.name!='artifact-hashes.json':
        data=path.read_bytes()
        hashes.append(dict(path=path.relative_to(OUT).as_posix(),bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
(OUT/'artifact-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8',newline='\n')
final=make_and_verify(2)
(LAB/'checkpoint-final.json').write_text(json.dumps(final,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(final,indent=2))
