from pathlib import Path
import hashlib,json,shutil,subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
logs=OUT/'logs';logs.mkdir(exist_ok=True)
log_files=list((ROOT/'build/logs').glob('*/*.log'))
selected=[]
for marker in ['CONTACT_ESCALATION_AUDIO: 65 checks, 0 failures','VISIBLE_WALL_AUDIO: 167 checks, 0 failures',
               'EFFECT_TIMING_TESTS: 43 checks, 0 failures','WINDOWS_IMPACT_TESTS: 16 checks, 0 failures',
               'APP_TESTS: 99 checks, 0 failures','Rewind: 61 checks, 0 failures','SCRIPT_PARSE: 406 scripts, 0 failures']:
    choices=[p for p in log_files if marker in p.read_text(encoding='utf-8',errors='replace')]
    assert choices,marker
    selected.append(max(choices,key=lambda p:p.stat().st_mtime))
for name in ['TestScript-34112','TestScript-41352','TestScript-28740']:
    selected.extend((ROOT/'build/logs'/name).glob('*.log'))
for source in set(selected): shutil.copy2(source,logs/(source.parent.name+'-'+source.name))
before_line=next(line for line in (ROOT/'build/logs/TestScript-34112/test-script.log').read_text().splitlines() if line.startswith('SLOW_WALL_AUDIO: '))
after_line=next(line for line in (ROOT/'build/logs/TestScript-41352/test-script.log').read_text().splitlines() if line.startswith('SLOW_WALL_AUDIO: '))
before_rows=json.loads(before_line.partition(': ')[2]);after_rows=json.loads(after_line.partition(': ')[2])
for row in before_rows:
    if row['sound_tick']<0: row['extra_dispatch_delay_ms']=None
assert all(row['extra_dispatch_delay_ms']==0 for row in after_rows)
(OUT/'comparison.json').write_text(json.dumps(dict(before=before_rows,after=after_rows),indent=2)+'\n',encoding='utf-8')

paths=['DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','docs/CONTACT_ESCALATION_AUDIO.md',
       'game/vehicle/visible_contact_audio.gd','game/tests/probe_slow_wall_audio.gd','game/tests/probe_slow_wall_audio.gd.uid',
       'game/tests/test_contact_escalation_audio.gd','game/tests/test_contact_escalation_audio.gd.uid']
scratch=ROOT/'build/contact-escalation-audio';before=scratch/'before';after=scratch/'after'
before.mkdir(parents=True,exist_ok=True);after.mkdir(parents=True,exist_ok=True)
rows=[]
for relative in paths:
    source=ROOT/relative;prior=OUT/'before'/relative
    target=after/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    if prior.exists():
        target=before/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(prior,target)
    rows.append(dict(file=relative,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),before_sha256=hashlib.sha256(prior.read_bytes()).hexdigest() if prior.exists() else None))
result=subprocess.run(['git','diff','--no-index','--binary','--','build/contact-escalation-audio/before','build/contact-escalation-audio/after'],cwd=ROOT,capture_output=True)
assert result.returncode==1,result.stderr.decode()
patch=result.stdout
for stage in ['before','after']:
    patch=patch.replace(('a/build/contact-escalation-audio/'+stage+'/').encode(),b'a/').replace(('b/build/contact-escalation-audio/'+stage+'/').encode(),b'b/')
(OUT/'scoped-change.patch').write_bytes(patch)
check=subprocess.run(['git','apply','--reverse','--check',str(OUT/'scoped-change.patch')],cwd=ROOT,capture_output=True)
(OUT/'patch-check.txt').write_text('reverse_check_exit='+str(check.returncode)+'\n'+check.stderr.decode(errors='replace'),encoding='utf-8')
assert check.returncode==0,check.stderr.decode()
(OUT/'source-hashes.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
report=dict(scoped_files=len(paths),retained_logs=len(set(selected)),reverse_check=0,
            new_checks=65,all_first_eligible_tick=True,physics_changed=False,acoustic_test_performed=False,
            known_warnings='Escalation 66 shutdown references; earlier timing 31; final timing clean. Initial parser missing unrelated night asset, final parser 406 passes.')
(OUT/'checkpoint-review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
