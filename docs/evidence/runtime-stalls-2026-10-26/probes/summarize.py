from pathlib import Path
import csv,hashlib,json,shutil,statistics

ROOT=Path.cwd(); WORK=ROOT/'build/runtime-stall-investigation-2026-10-26'; OUT=ROOT/'docs/evidence/runtime-stalls-2026-10-26'
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def log_text(path):
    data=path.read_bytes()
    return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig',errors='replace')

runs=[]; cases=[]; chrome=[]
for run_id,path in enumerate(sorted(OUT.glob('*/trace.json')),1):
    data=json.loads(path.read_text(encoding='utf-8'))
    assert not data['failures'],(path,data['failures'])
    run_name=path.parent.name
    runs.append({'path':str(path.relative_to(OUT)).replace('\\','/'),'sha256':digest(path),'app_loads':len(data['loads']),'failures':data['failures'],'options':data['options'],'source_hashes':data.get('source_hashes',[])})
    chrome.append({'ph':'M','pid':run_id,'tid':1,'name':'process_name','args':{'name':run_name}})
    for tid,name in [(1,'Frame intervals'),(2,'App call spans (wall; may await)'),(3,'Case')]:
        chrome.append({'ph':'M','pid':run_id,'tid':tid,'name':'thread_name','args':{'name':name}})
    for load in data['loads']:
        phase=load['phase']; rows=[r for r in data['frames'] if r['begin_context']['phase']==phase]
        worst=max(rows,key=lambda r:r['wall_us'])
        render=max((r.get('draw_end_us',r['begin_us'])-r.get('draw_begin_us',r['begin_us'])) for r in rows)/1000
        update=max((r.get('draw_begin_us',r['begin_us'])-r['begin_us']) for r in rows)/1000
        entry=next((e for e in data['events'] if e['context'].get('phase')==phase and e['label']=='initial_presentation:begin'),None)
        warmup=next((r for r in rows if entry and r['begin_us']<=entry['at_us']<r['end_us']),None)
        cases.append({'run':run_name,'renderer':data['renderer'],'case':phase,'entry_ms':load['wall_us']/1000,'peak_frame_ms':worst['wall_us']/1000,'peak_render_interval_ms':render,'peak_update_interval_ms':update,'first_warmup_render_ms':(warmup['draw_end_us']-warmup['draw_begin_us'])/1000 if warmup and 'draw_end_us' in warmup else None,'verification':load.get('verification')})
        chrome.append({'ph':'X','pid':run_id,'tid':3,'ts':rows[0]['begin_us'],'dur':rows[-1]['end_us']-rows[0]['begin_us'],'name':phase,'cat':'case'})
    for frame in data['frames']:
        begin=frame['begin_us']; pre=frame.get('draw_begin_us',begin); post=frame.get('draw_end_us',pre); end=frame['end_us']
        for label,a,b in [('Update / coroutine dispatch',begin,pre),('Render call interval',pre,post),('After draw / scheduling',post,end)]:
            if b>a: chrome.append({'ph':'X','pid':run_id,'tid':1,'name':label,'cat':label,'ts':a,'dur':b-a,'args':{'engine_frame':frame['engine_frame'],'begin_context':frame['begin_context'],'draw_context':frame.get('draw_context',{})}})
    for event in data['events']:
        if 'duration_us' in event: chrome.append({'ph':'X','pid':run_id,'tid':2,'name':event['label'],'cat':'App elapsed call','ts':event['start_us'],'dur':event['duration_us'],'args':{'context':event['context'],'facts':event.get('facts',{})}})

(OUT/'cases.json').write_text(json.dumps(cases,indent=2)+'\n',encoding='utf-8')
with (OUT/'cases.csv').open('w',newline='',encoding='utf-8') as file:
    keys=['run','renderer','case','entry_ms','peak_frame_ms','peak_render_interval_ms','peak_update_interval_ms','first_warmup_render_ms']
    writer=csv.DictWriter(file,keys,extrasaction='ignore'); writer.writeheader(); writer.writerows(cases)
(OUT/'timeline.perfetto.json').write_text(json.dumps({'traceEvents':chrome,'displayTimeUnit':'ms'}),encoding='utf-8')

verified=[r for r in cases if r['run'].endswith('-verify-state')]
assert len(verified)==10
baseline=verified[0]['verification']
for row in verified:
    value=row['verification']
    assert value['effects']==baseline['effects'] and value['live_emitters']==baseline['live_emitters'],row['case']
    assert value['tick']==0 and value['elapsed_ticks']==0 and value['countdown']==360
    assert value['trail_capacity']==16384 and value['trail_cursor']==0 and value['trail_visible']==0
    assert not value['weather_warming']

cpu={}
for suffix,name in [('cpu-details','original'),('cpu-details-memo-grid','memoized')]:
    data=json.loads(next(OUT.glob('*-'+suffix+'/trace.json')).read_text(encoding='utf-8'))
    cpu[name]={event['label']:event['duration_us']/1000 for event in data['events'] if event['label'].startswith('cpu_')}

(OUT/'logs').mkdir(exist_ok=True); logs=[]
for path in sorted(WORK.glob('*.log')):
    target=OUT/'logs'/path.name; shutil.copyfile(path,target)
    messages=[line for line in log_text(path).splitlines() if 'SCRIPT ERROR:' in line or line.startswith(('ERROR:','WARNING:','FAIL:'))]
    logs.append({'path':'logs/'+path.name,'sha256':digest(target),'bytes':target.stat().st_size,'issues':messages})
shutil.copytree(WORK/'before',OUT/'before',dirs_exist_ok=True)
(OUT/'probes').mkdir(exist_ok=True)
for path in list(WORK.glob('*.gd'))+list(WORK.glob('*.py'))+list(WORK.glob('*.json')):
    shutil.copyfile(path,OUT/'probes'/path.name)

report={
 'date':'2026-10-26','requirements':['RSI01','RSI02','RSI03','RSI04'],
 'scope':'Investigate the previously reported runtime stalls; shipping runtime files are not edited by this task',
 'engine':'4.7.2.stable.official.ed1daf0bf','hardware':'Windows NVIDIA RTX 3090 / NVIDIA616.92; Compatibility and desktop Vulkan Mobile',
 'environment':'Separate APPDATA/LOCALAPPDATA profile; BMT_API_URL/BMT_DEV_AUTH_KEY empty; offline owned Star fixture',
 'findings':[
  {'id':'RSI01','cause':'Bulk startup of20 temporary GPUParticles3D warm-up nodes','source':'game/vehicle/effect_render_preparation.gd::begin','evidence':'Interleaved same-process controls retain200+ms render intervals; removing only particle proxies removes them. Zero preprocess, keeping nodes and removing finish/canvas do not remove them. Delay occurs before effects_end.'},
  {'id':'RSI02','cause':'SkidTrails creates identical new Shader resources on each race','source':'game/vehicle/skid_trails.gd::_trail_material','evidence':'Removing only trail proxy removes approximately50ms first warmup render interval. Shared immutable shader keeps separate ShaderMaterials and removes repeated interval after first shared use.'},
  {'id':'RSI03','cause':'Compact front fitting generation; repeated front_skin corner evaluation in nose tiles','source':'game/vehicle/compact_detail.gd::_front/_nose_band/_nose_tile','original_ms':cpu['original'],'prototype_ms':cpu['memoized'],'geometry_validation':'Full and simple model mesh-array/transform/material-source signatures exact in cpu-parity.log'},
  {'id':'RSI04','cause':'Cold renderer first use and remaining CPU preparation','evidence':'World pack approximately4ms and warm instantiate approximately1ms are not the dominant intervals. Cold first use varies with renderer/shared background load. Staging still leaves73-91ms warm peaks, and CPU-side preparation remains.'}
 ],
 'runs':runs,'app_load_attempts':sum(r['app_loads'] for r in runs),'cases':cases,
 'verified_observables':{'cases':len(verified),'unchanged':baseline,'shader_code':'Shared trail shader source equality asserted on reuse; ShaderMaterials remain separate'},
 'cpu_parity_log':'logs/cpu-parity.log','timeline':'timeline.perfetto.json','csv':'cases.csv',
 'interpretation_limits':[
  'Multiple unrelated Godot processes were active; none stopped. No matched cleared driver-cache or physical-device comparison.',
  'Cold denotes the first fixture load in that engine process, not a clean device/driver cache.',
  'Frame pre/post intervals include native renderer/driver waits. Per-viewport timings are returned asynchronously and do not identify a specific native blocking API or prove whole-GPU saturation.',
  'No native driver/engine stack capture was taken; compilation/buffer initialization/synchronization are not individually attributed for particle startup.',
  'Ablations intentionally skip selected warm-up work only inside diagnostic copies; they are not fixes.',
  'Staged particle prototype retains all20 particles and canvas and frozen game/trail observables, but is not a shipping implementation: cancellation/pressure/all-theme/all-car/first-real-effect validation remains.',
  'Staging improves frame peaks at a cost in loading wall time. Shared shader and memoized-grid prototypes are not integrated into production.',
  'One early skip-effects run reports4 leaked ObjectDB instances/1 resource at exit. Later sequenced runs with bounded teardown delay do not report this; raw finding retained.',
  'Sandbox root-certificate-store startup error retained; no APK/device/authentication/purchase/deployment/owner restart/root-index mutation.'
 ],
 'references':[
  'https://docs.godotengine.org/en/stable/classes/class_renderingserver.html',
  'https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html',
  'https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html',
  'https://github.com/godotengine/godot/blob/master/drivers/gles3/storage/particles_storage.cpp'
 ],
 'commands':'commands.txt','raw_logs':logs,
 'checkpoint':{'path':'checkpoint.patch','validation':'checkpoint-validation.json','source_manifest':'source-manifest.json'},
}
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('Summarized',len(runs),'trace runs,',report['app_load_attempts'],'App attempts,',len(verified),'verified state cases.')
for row in verified: print(row['case'],round(row['peak_frame_ms'],3),round(row['first_warmup_render_ms'] or 0,3),round(row['entry_ms'],3))
