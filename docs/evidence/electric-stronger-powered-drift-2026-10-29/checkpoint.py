import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
paths={'game/resources/cars/electric.tres','backend/tests/fixtures/verified_oval.json',
       'docs/ELECTRIC_STRONGER_POWERED_DRIFT_2026_10_29.md',
       'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md'}
for name in ['test_electric_drift_easier.gd','test_electric_acceleration.gd',
             'test_electric_turning_tighter.gd','test_electric_brake_reverse.gd',
             'test_electric_stronger_power_drift.gd','probe_electric_stronger_power_drift.gd']:
    paths.add('game/tests/'+name)
    if name in ['test_electric_stronger_power_drift.gd','probe_electric_stronger_power_drift.gd'] and (ROOT/('game/tests/'+name+'.uid')).exists():
        paths.add('game/tests/'+name+'.uid')
for file in ['before/game/resources/cars/electric.tres','before-manifest.json']:
    paths.add((OUT/file).relative_to(ROOT).as_posix())
baseline=json.loads((OUT/'before-hashes.json').read_text())
protected=[path for path in baseline if path not in ['game/resources/cars/electric.tres','backend/tests/fixtures/verified_oval.json']]
changed=[path for path in protected if sha(ROOT/path)!=baseline[path]]
work=ROOT/'tmp'/('electric-stronger-drift-checkpoint-'+str(time.time_ns()))
before,after,applied=work/'before',work/'after',work/'applied'
for relative in sorted(paths):
    source=OUT/'before'/relative
    target=before/relative
    if relative in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
        content=(ROOT/relative).read_bytes().decode()
        content=re.sub(r'<!-- ELECTRIC-STRONGER-POWERED-DRIFT-20261029 -->.*?<!-- /ELECTRIC-STRONGER-POWERED-DRIFT-20261029 -->\r?\n\r?\n','',content,count=1,flags=re.S)
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(content.encode())
    elif source.exists():
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,target)
    target=after/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/relative,target)
subprocess.run(['git','init','--quiet',str(work)],check=True)
subprocess.run(['git','-C',str(work),'config','core.autocrlf','false'],check=True)
result=subprocess.run(['git','diff','--no-index','--binary','--','before','after'],cwd=work,capture_output=True)
assert result.returncode==1
patch=result.stdout.replace(b'a/before/',b'a/').replace(b'b/after/',b'b/').replace(b'a/after/',b'a/').replace(b'b/before/',b'b/')
path=OUT/'task.patch'
path.write_bytes(patch)
shutil.copytree(before,applied)
subprocess.run(['git','init','--quiet',str(applied)],check=True)
subprocess.run(['git','-C',str(applied),'config','core.autocrlf','false'],check=True)
for arguments in [['--check'],[],['--reverse','--check'],['--reverse']]:
    result=subprocess.run(['git','apply',*arguments,str(path)],cwd=applied,capture_output=True)
    assert result.returncode==0,result.stderr.decode(errors='replace')
    if arguments==[]: assert all(sha(applied/file)==sha(after/file) for file in paths)
assert all((applied/file).exists()==(before/file).exists() for file in paths)
assert all(sha(applied/file)==sha(before/file) for file in paths if (before/file).exists())
report=dict(files=len(paths),patch_sha256=sha(path),patch_bytes=path.stat().st_size,
            forward_exact=True,reverse_exact=True,main_index_untouched=True,
            protected_files_exact=len(protected)-len(changed),concurrent_protected_changes_preserved=changed,
            hashes={file:sha(ROOT/file) for file in sorted(paths)})
(OUT/'checkpoint.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({key:value for key,value in report.items() if key!='hashes'}))
