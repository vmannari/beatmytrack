"""Round-trip the owned source/assets in an isolated Git repository."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
sha=lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
baseline=json.loads((OUT/'hashes-before-derivatives.json').read_text())
protected=[p for p in baseline if '/electric_coachwork_v17/' in p or p.startswith('game/resources/cars/')]
concurrent=[p for p in protected if sha(ROOT/p)!=baseline[p]]
assert all(p.startswith('game/resources/cars/') for p in concurrent), concurrent
paths={p for p in baseline if p.startswith('game/assets/') and p not in protected and sha(ROOT/p)!=baseline[p]}
paths.add('game/vehicle/electric_coachwork.gd')
# Include the exact references needed to rerun the owned tests/review controls.
paths.add((OUT/'before/game/vehicle/electric_coachwork.gd').relative_to(ROOT).as_posix())
paths.add((OUT/'aero-v19.gd.txt').relative_to(ROOT).as_posix())
reference=OUT/'intermediate-v19-resources'
paths.add((reference/'manifest.json').relative_to(ROOT).as_posix())
for entry in json.loads((reference/'manifest.json').read_text())['meshes']:
    if entry['part'] in ['Windscreen','Windscreen_simple']:
        paths.add((reference/entry['file']).relative_to(ROOT).as_posix())
for name in ['test_volt_cabin_correction.gd','review_volt_cabin_correction.gd','test_volt_short_bonnet.gd']:
    paths.add('game/tests/'+name)
    if (ROOT/('game/tests/'+name+'.uid')).exists(): paths.add('game/tests/'+name+'.uid')
paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'game/assets/vehicles/electric_coachwork_v20').iterdir() if p.is_file())
work=ROOT/'tmp'/('volt-cabin-checkpoint-'+str(time.time_ns()))
before,after,applied=work/'before',work/'after',work/'applied'
def restore_entry(current,previous,key):
    def span(value):
        start=re.search(re.escape(json.dumps(key))+r'\s*:\s*',value).end()
        _,length=json.JSONDecoder().raw_decode(value[start:])
        return start,start+length
    a,b=span(current)
    x,y=span(previous)
    return current[:a]+previous[x:y]+current[b:]
for relative in sorted(paths):
    source=OUT/'before'/relative if relative=='game/vehicle/electric_coachwork.gd' else OUT/'task-base'/relative
    if source.exists():
        target=before/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,target)
        if relative in ['game/assets/vehicles/racing_simple_v1/manifest.json','game/assets/garage/previews_v1/provenance.json']:
            previous=source.read_text(encoding='utf-8')
            current=(ROOT/relative).read_text(encoding='utf-8')
            current=restore_entry(current,previous,'electric')
            if relative.endswith('provenance.json'): current=restore_entry(current,previous,'game/vehicle/electric_coachwork.gd')
            target.write_text(current,encoding='utf-8',newline='')
    target=after/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/relative,target)
subprocess.run(['git','init','--quiet',str(work)],check=True)
subprocess.run(['git','-C',str(work),'config','core.autocrlf','false'],check=True)
result=subprocess.run(['git','diff','--no-index','--binary','--','before','after'],cwd=work,capture_output=True)
assert result.returncode==1,result.stderr.decode(errors='replace')
patch=result.stdout.replace(b'a/before/',b'a/').replace(b'b/after/',b'b/').replace(b'a/after/',b'a/').replace(b'b/before/',b'b/')
patch_path=OUT/'task.patch'
patch_path.write_bytes(patch)
shutil.copytree(before,applied)
subprocess.run(['git','init','--quiet',str(applied)],check=True)
subprocess.run(['git','-C',str(applied),'config','core.autocrlf','false'],check=True)
for arguments in [['--check'],[],['--reverse','--check'],['--reverse']]:
    result=subprocess.run(['git','apply',*arguments,str(patch_path)],cwd=applied,capture_output=True)
    assert result.returncode==0,result.stderr.decode(errors='replace')
    if arguments==[]: assert all((applied/p).exists() and sha(applied/p)==sha(after/p) for p in paths)
assert all((applied/p).exists()==(before/p).exists() for p in paths)
assert all(sha(applied/p)==sha(before/p) for p in paths if (before/p).exists())
report=dict(files=len(paths),patch_sha256=sha(patch_path),patch_bytes=patch_path.stat().st_size,
            forward_exact=True,reverse_exact=True,protected_files_exact=len(protected)-len(concurrent),
            concurrent_configuration_changes_preserved=concurrent,main_index_untouched=True,
            shared_manifests_keep_concurrent_context=True,
            hashes={p:sha(ROOT/p) for p in sorted(paths)})
(OUT/'checkpoint.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='hashes'}))
