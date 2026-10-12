from pathlib import Path
import hashlib,json,re,shutil,subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
capture=ROOT/'build/direct-collision-output-2026-10-09'
for name in ['ready.json','events.json','loopback.pcm','packets.csv','capture-meta.txt','timing-report.json','direct-review.json']:
    shutil.copy2(capture/name,OUT/name)
# Preserve the concurrent wet-road deferral in this shared file. Construct the
# task baseline by removing only this task's diagnostic additions from current.
audio=(ROOT/'game/vehicle/vehicle_audio.gd').read_text(encoding='utf-8')
baseline=audio.replace('var collision_trace_enabled: bool = false\nvar last_impact_route: String = "none"\n','')
baseline=baseline.replace('\tcollision_trace_enabled = OS.is_debug_build() and OS.get_cmdline_user_args().has("--collision-audio-trace")\n','')
baseline=baseline.replace('\tvar requested_us: int = int(Time.get_unix_time_from_system()*1000000.0) if collision_trace_enabled else 0\n\tvar count_before: int = impact_count\n\tvar cooldown_before: float = impact_cooldown\n','')
start=baseline.index('\tif collision_trace_enabled and (state.collision_impulse')
end=baseline.index('\nfunc collision(',start)
baseline=baseline[:start]+'\n'+baseline[end:]
baseline=baseline.replace('\tvar native_played: bool = clip in IMPACTS and windows_impacts.play(IMPACTS.find(clip),amplitude,pitch,slot)\n\tif clip in IMPACTS and collision_trace_enabled: last_impact_route = "windows_raw" if native_played else "godot"\n\tif native_played:\n','\tif clip in IMPACTS and windows_impacts.play(IMPACTS.find(clip),amplitude,pitch,slot):\n')
assert 'collision_trace_enabled' not in baseline
(OUT/'before/game/vehicle/vehicle_audio.gd').write_text(baseline,encoding='utf-8')
logs=OUT/'logs';logs.mkdir(exist_ok=True)
files=list((ROOT/'build/logs').glob('*/*.log'))
markers=['COLLISION_TRACE_TESTS: 9 checks, 0 failures','EFFECT_TIMING_TESTS: 43 checks, 0 failures','WINDOWS_IMPACT_TESTS: 16 checks, 0 failures','SCRIPT_PARSE: 414 scripts, 0 failures']
selected=[]
for marker in markers:
    choices=[p for p in files if marker in p.read_text(encoding='utf-8',errors='replace')]
    assert choices,marker
    selected.append(max(choices,key=lambda p:p.stat().st_mtime))
for name in ['TestScript-43376','TestScript-36420','TestScript-7216','TestScript-12608']:
    selected.extend((ROOT/'build/logs'/name).glob('*.log'))
for source in set(selected): shutil.copy2(source,logs/(source.parent.name+'-'+source.name))
paths=['DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','docs/DIRECT_COLLISION_TIMING.md','game/vehicle/vehicle_audio.gd','scripts/review_direct_collision_output.py']
for name in ['probe_direct_collision_output','probe_cached_direct_walls','run_collision_trace_app','test_collision_trace']:
    paths.extend(['game/tests/'+name+'.gd','game/tests/'+name+'.gd.uid'])
scratch=ROOT/'build/direct-collision-review';before=scratch/'before';after=scratch/'after'
before.mkdir(parents=True,exist_ok=True);after.mkdir(parents=True,exist_ok=True)
rows=[]
for relative in paths:
    source=ROOT/relative;prior=OUT/'before'/relative
    target=after/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    if prior.exists():
        target=before/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(prior,target)
    rows.append(dict(file=relative,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),before_sha256=hashlib.sha256(prior.read_bytes()).hexdigest() if prior.exists() else None))
result=subprocess.run(['git','diff','--no-index','--binary','--','build/direct-collision-review/before','build/direct-collision-review/after'],cwd=ROOT,capture_output=True)
assert result.returncode==1,result.stderr.decode()
patch=result.stdout
for stage in ['before','after']:
    patch=patch.replace(('a/build/direct-collision-review/'+stage+'/').encode(),b'a/').replace(('b/build/direct-collision-review/'+stage+'/').encode(),b'b/')
(OUT/'scoped-change.patch').write_bytes(patch)
check=subprocess.run(['git','apply','--reverse','--check',str(OUT/'scoped-change.patch')],cwd=ROOT,capture_output=True)
(OUT/'patch-check.txt').write_text('reverse_check_exit='+str(check.returncode)+'\n'+check.stderr.decode(errors='replace'),encoding='utf-8')
assert check.returncode==0,check.stderr.decode()
(OUT/'source-hashes.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
report=dict(scoped_files=len(paths),logs=len(set(selected)),reverse_check=0,direct_checks=30,trace_checks=9,reported_delay_reproduced=False,normal_app_hit_traces=0,physics_or_sound_behavior_changed=False,acoustic_recording=False)
(OUT/'checkpoint-review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
