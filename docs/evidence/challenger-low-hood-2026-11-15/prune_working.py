"""Remove this task's disposable process profiles and rejected working arrays."""
from pathlib import Path
import json,shutil,stat
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=(ROOT/'build'/OUT.name).resolve()
assert BUILD.parent==(ROOT/'build').resolve() and BUILD.name==OUT.name
targets=[BUILD/name for name in ['checks','profile','assets','source-checkpoint','before','converted','native','views-before','views-candidate','views-final','views-final-close','app','opacity','baseline.json','candidate.json']]
receipt=[]
def clear_readonly(function,path,error):
    resolved=Path(path).resolve()
    assert resolved.is_relative_to(BUILD) and not Path(path).is_symlink()
    Path(path).chmod(stat.S_IWRITE|stat.S_IREAD)
    function(path)
for target in targets:
    resolved=target.resolve()
    assert resolved.is_relative_to(BUILD) and resolved!=BUILD
    if not target.exists():continue
    assert not target.is_symlink()
    if target.is_dir():
        size=sum(p.stat().st_size for p in target.rglob('*') if p.is_file())
        shutil.rmtree(target,onerror=clear_readonly)
    else:size=target.stat().st_size;target.unlink()
    receipt.append({'verified_absolute_target':str(resolved),'removed_bytes':size})
(OUT/'working-cleanup.json').write_text(json.dumps({'task_root':str(BUILD),'removed':receipt,'bytes':sum(r['removed_bytes'] for r in receipt)},indent=2))
print('TASK_WORKING_CLEANUP',sum(r['removed_bytes'] for r in receipt),'bytes; final evidence and production resources retained.')
