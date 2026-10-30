from pathlib import Path
import datetime
import difflib
import hashlib
import json
import re
import shutil

ROOT=Path.cwd()
LAB=ROOT/'build/race-optional-work-fixes-2026-10-27'
OUT=ROOT/'docs/evidence/race-optional-work-fixes-2026-10-27'
OUT.mkdir(parents=True,exist_ok=True)


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')


def copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)


baseline=json.loads((LAB/'before.json').read_text(encoding='utf-8'))
task_after=LAB/'task-after'
app_before=(LAB/'before/game/core/app.gd').read_text(encoding='utf-8')
app=app_before
changes=[
    ('var cloud_starting: bool = false\n','var cloud_starting: bool = false:\n\tset(value):\n\t\tif cloud_starting == value: return\n\t\tcloud_starting = value\n\t\tif is_inside_tree(): _wake_optional_work.call_deferred()\n'),
    ('\treturn session != null and session.finished\n','\treturn session != null and session.finished\n\nfunc _wake_optional_work() -> void:\n\tif not is_inside_tree() or is_queued_for_deletion(): return\n\tpreload("res://backend/menu_snapshot_writer.gd").resume()\n\tif is_instance_valid(_garage_preloader): _garage_preloader.invalidate()\n'),
    ('func _ready() -> void:\n','func _ready() -> void:\n\tpreload("res://backend/menu_snapshot_writer.gd").shared().background_allowed = _background_work_allowed\n'),
    ('func _show_screen(next: String) -> void:\n','func _show_screen(next: String) -> void:\n\t_wake_optional_work.call_deferred()\n'),
    ('func _race_menu_visible(value: bool) -> void:\n','func _race_menu_visible(value: bool) -> void:\n\t_wake_optional_work.call_deferred()\n')]
for before,after in changes:
    assert app.count(before)==1,before
    app=app.replace(before,after,1)
    assert after in (ROOT/'game/core/app.gd').read_text(encoding='utf-8'),after
(task_after/'game/core').mkdir(parents=True,exist_ok=True)
(task_after/'game/core/app.gd').write_text(app,encoding='utf-8',newline='\n')
sources=[]
for row in baseline['files']:
    relative=row['path']
    if relative!='game/core/app.gd':
        # These four reviewed files contained only task changes when frozen.
        copy(LAB/'after-runtime'/relative,task_after/relative)
        if sha(ROOT/relative)!=sha(task_after/relative):
            assert relative=='game/ui/garage_preloader.gd',relative
            current=(ROOT/relative).read_text(encoding='utf-8')
            for own_block in [
                'func invalidate() -> void:\n\t_next_audit=0\n\tif not evicted: set_process(true)',
                '\tif evicted:\n\t\tset_process(not _pending.is_empty())\n\t\treturn',
                '\t\t# Consume outstanding threaded reads before sleeping. Menu/lifecycle\n\t\t# events wake us; active racing does not need an empty reset each frame.\n\t\tset_process(not _pending.is_empty())',
                'func evict() -> void:\n\tevicted=true\n\t_reset()\n\tset_process(not _pending.is_empty())',
                '\t\tlast_input=Time.get_ticks_msec()\n\t\tinvalidate()']:
                assert own_block in current,own_block
            delta='\n'.join(difflib.unified_diff((task_after/relative).read_text(encoding='utf-8').splitlines(),current.splitlines(),fromfile='task-only-preloader',tofile='observed-preloader',n=2))+'\n'
            (OUT/'excluded-concurrent-preloader.diff').write_text(delta,encoding='utf-8',newline='\n')
    copy(LAB/'before'/relative,OUT/'before'/relative)
    copy(task_after/relative,OUT/'after'/relative)
    copy(ROOT/relative,OUT/'observed-working-tree'/relative)
    sources.append(dict(path=relative,before=row['sha256'],task_after=sha(task_after/relative),observed=sha(ROOT/relative)))
observed_app=(ROOT/'game/core/app.gd').read_text(encoding='utf-8')
other_app='\n'.join(difflib.unified_diff(app.splitlines(),observed_app.splitlines(),fromfile='task-only-app',tofile='observed-app',n=2))+'\n'
(OUT/'excluded-concurrent-app.diff').write_text(other_app,encoding='utf-8',newline='\n')

primary=['focused-headless-v4','focused-native','app-headless','header-native','preload-headless-final','preload-native-final','parser-latest']
tests=[]
for label in primary:
    execution=json.loads((LAB/(label+'-execution.json')).read_text(encoding='utf-8'))
    assert execution['exit']==0,(label,execution)
    text=(LAB/(label+'.log')).read_text(encoding='utf-8',errors='replace')
    errors=[line for line in text.splitlines() if any(token in line for token in ['SCRIPT ERROR','FAIL:','AUDIT_FAIL:','leaked at exit','resources still in use'])]
    assert not errors,(label,errors)
    tests.append(dict(label=label,execution=execution,summaries=[line for line in text.splitlines() if re.search(r'(checks|SCRIPT_PARSE|GARAGE_PRELOAD)',line)],
                      environment_errors=[line for line in text.splitlines() if 'ERROR:' in line]))
for source in LAB.iterdir():
    if source.is_file() and source.name!='checkpoint-final.json' and source.suffix in {'.json','.log','.py','.txt'}:
        copy(source,OUT/source.name)
for folder in ['checks','outputs']:
    for source in (LAB/folder).rglob('*'):
        if source.is_file() and source.suffix in {'.gd','.json','.png'}:
            copy(source,OUT/source.relative_to(LAB))
new_files=['game/tests/test_race_optional_work.gd']
uid=ROOT/'game/tests/test_race_optional_work.gd.uid'
if uid.exists():new_files.append(uid.relative_to(ROOT).as_posix())
for name in new_files:copy(ROOT/name,OUT/'after'/name)

focused={}
for label in ['focused-headless-v4','focused-native']:
    data=json.loads((LAB/'outputs'/label/'report.json').read_text(encoding='utf-8'))
    changed=[key for key,value in data['sources_at_start'].items() if data['sources_at_end'].get(key)!=value]
    focused[label]=dict(checks=data['checks'],failures=data['failures'],source_changes=changed,natural_window=data['observations']['natural_window'],
                        deferred_snapshot=data['observations']['deferred_snapshot'])
report=dict(date='2026-10-27',timezone='Europe/Helsinki',completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            document=dict(path='docs/RACE_OPTIONAL_WORK_FIXES_2026_10_27.md',sha256=sha(ROOT/'docs/RACE_OPTIONAL_WORK_FIXES_2026_10_27.md')),
            requirements={'RTF05A':'Block new optional snapshot dispatch while racing; preserve latest scoped RAM and active atomic writes',
                          'RTF05B':'Defer completed header image publication and late draw readback until eligible; revalidate ownership/appearance',
                          'RTF06A':'Assemble pause-only presentation key only while paused; preserve all invalidations',
                          'RTF06B':'Sleep empty/evicted Garage preloader after read reaping; wake on navigation/loading/appearance/lifecycle events',
                          'R01':'Focused real-App regression plus retained header/App/Garage/parser checks',
                          'Q01':'No Android or FPS certification; cold loading is outside this task'},
            runtime_sources=sources,new_test_files=new_files,tests=tests,focused=focused,
            inherited_fixture=dict(path='game/tests/audit_race_work_recheck.gd',sha256=sha(ROOT/'game/tests/audit_race_work_recheck.gd'),scope='Historical counterexample method overridden; original demand assertions inherited unchanged'),
            concurrent_work='Observed App includes unrelated road-material editor controls/method; the observed preloader later gained a first-menu-draw/early-construction gate. Both are excluded from task-only after images. All own preloader sleep/wake blocks are checked intact; final retained preload suites and parser run against the combined working tree. Render-preparation/cache, result-tick-rounding, backend and other owner changes are preserved. Tests use the actual shared working tree; source start/end hashes are retained.',
            test_copy_changes='Known report output redirects and explicit empty backend.cfg only; existing assertions and fixture reads preserved. New fixture extends the earlier audit and retains its original demand-work assertions while overriding historical counterexamples.',
            failures_retained=['focused-headless.log and parser.log: initial SceneTree fixture used get_tree(); corrected to self',
                               'focused-headless-v2.log: transient wake observation plus synthetic appearance state rolled back by camera-save fixture; only owned process timed out at 360s',
                               'focused-headless-v3.log: isolated camera preferences lacked a parent directory; final fixture creates it',
                               'All Godot runs report the known sandbox root certificate store error; no error policy suppressed'],
            not_performed=['Physical-device attachment query or test','APK/AAB export/install','Real authentication, payment, provider or player data operation',
                           'Backend/live mutation/deployment','Owner process restart','Root Git staging/commit/merge','Whole-suite or runtime 10/10 certification'])
write(OUT/'report.json',report)
write(OUT/'source-hashes.json',sources)
print(json.dumps(dict(primary_tests=[dict(label=t['label'],summary=t['summaries']) for t in tests],focused_source_changes={label:row['source_changes'] for label,row in focused.items()},files=len(list(OUT.rglob('*')))),ensure_ascii=False))
