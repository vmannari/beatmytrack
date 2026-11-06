"""Check this task's review patch in an owned tree; never write the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence=Path(__file__).resolve().parent
root=evidence.parents[2]
changed=['game/core/app.gd','game/core/features/selected_track.gd','game/core/features/daily.gd',
         'game/core/features/rivalry.gd','game/ui/track_of_day_page.gd','game/editor/road_preparation.gd',
         'game/editor/editor_memory.gd','game/track/native_track_visual.gd',
         'game/track/prepared_world_cache.gd','game/track/winter_snow_wind.gd']
trackers=['AGENTS.md','DEVELOPMENT_STATUS.md']
tests=['inspect_winter_retention','inspect_winter_clone','test_selected_events',
       'test_selected_scenery_retention','test_selective_scenery_budget','test_retained_winter_surfaces',
       'test_daily_event_install','test_before_selected_free_race','test_active_winter_sky_policy']
added=['game/race/selected_event.gd','docs/SELECTED_EVENTS_AND_SCENERY_RETENTION_2026_11_04.md']
added+=['game/tests/'+name+'.gd' for name in tests]
added+=[path+'.uid' for path in added.copy() if path.endswith('.gd') and (root/(path+'.uid')).exists()]
added+=[path.relative_to(root).as_posix() for path in sorted((evidence/'before').rglob('*')) if path.is_file()]
added+=[path.relative_to(root).as_posix() for path in sorted((evidence/'experiments').glob('*.txt'))]
added+=[(evidence/name).relative_to(root).as_posix() for name in (
    'run_check.py','run_retained_checks.py','run_final_controls.py','run_accepted_checks.py','summarize.py','checkpoint.py')]
marker='<!-- SELECTED-EVENTS-RETENTION-20261104 -->'
end_marker='<!-- /SELECTED-EVENTS-RETENTION-20261104 -->'
before,after,parts={},{},[]
for path in changed+trackers+added:
    new=(root/path).read_bytes().replace(b'\r\n',b'\n')
    old=b''
    if path in changed:
        old=(evidence/'before'/path).read_bytes().replace(b'\r\n',b'\n')
    elif path in trackers:
        # Concurrent tracker changes remain identical on both patch sides.
        text=new.decode('utf-8')
        assert text.count(marker)==1 and text.count(end_marker)==1
        start=text.index(marker); end=text.index(end_marker)+len(end_marker)
        if text[end:end+2]=='\n\n': end+=2
        elif text[end:end+1]=='\n': end+=1
        old=(text[:start]+text[end:]).encode('utf-8')
    before[path],after[path]=old,new
    parts.append(f'diff --git a/{path} b/{path}\n')
    if path in added: parts.append('new file mode 100644\n')
    parts.extend(difflib.unified_diff(old.decode().splitlines(keepends=True),new.decode().splitlines(keepends=True),
        fromfile='/dev/null' if path in added else 'a/'+path,tofile='b/'+path))
patch=evidence/'task.patch'
patch.write_bytes(''.join(parts).encode('utf-8'))
owned=root/'build/selected-events-retention-20261104'/('checkpoint-'+str(time.time_ns()))
owned.mkdir(parents=True)
assert owned.resolve().is_relative_to((root/'build/selected-events-retention-20261104').resolve())
for path in changed+trackers:
    target=owned/path; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(before[path])
commands=[]
for args in (('--check',),(),('--reverse','--check'),('--reverse',)):
    command=['git','apply','--directory='+owned.relative_to(root).as_posix(),*args,str(patch)]
    result=subprocess.run(command,cwd=root,capture_output=True,text=True)
    commands.append({'command':command,'exit_code':result.returncode,'output':result.stdout+result.stderr})
    assert result.returncode==0,result.stderr
    if not args: assert all((owned/path).read_bytes().replace(b'\r\n',b'\n')==after[path] for path in after)
assert all((owned/path).read_bytes().replace(b'\r\n',b'\n')==before[path] for path in changed+trackers)
assert all(not (owned/path).exists() for path in added)
(evidence/'checkpoint.json').write_text(json.dumps({'files':list(after),'commands':commands,
    'forward_content_exact':True,'reverse_content_exact':True,'main_index_written':False,
    'patch_sha256':hashlib.sha256(patch.read_bytes()).hexdigest(),
    'source_sha256':{path:hashlib.sha256(after[path]).hexdigest() for path in after}},indent=2)+'\n',encoding='utf-8')
print('Task-only patch forward/reverse/content checks pass; main index unchanged.')
