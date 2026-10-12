from pathlib import Path
import hashlib,json,shutil,subprocess,wave
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
scratch=ROOT/'build/shared-collision-audio-2026-10-09'
for folder in ['before','after','controls']:
    target=OUT/'captures'/folder;target.mkdir(parents=True,exist_ok=True)
    for source in (scratch/folder).iterdir():
        if source.is_file() and source.name!='armed': shutil.copy2(source,target/source.name)
direct=OUT/'captures/direct-after';direct.mkdir(parents=True,exist_ok=True)
for name in ['ready.json','events.json','loopback.pcm','packets.csv','capture-meta.txt','timing-report.json','direct-review.json']:
    shutil.copy2(ROOT/'build/direct-collision-output-2026-10-09'/name,direct/name)
shutil.copy2(scratch/'review.json',OUT/'review.json')
shutil.copy2(ROOT/'build/windows_audio/export-review.json',OUT/'android-export-review.json')
logs=OUT/'logs';logs.mkdir(exist_ok=True)
logfiles=list((ROOT/'build/logs').glob('*/*.log'))
selected=[]
for marker in ['WINDOWS_IMPACT_TESTS: 18 checks, 0 failures','DIRECT_HIT_BODY_AUDIO: 5 checks, 0 failures','EFFECT_TIMING_TESTS: 43 checks, 0 failures','CONTACT_ESCALATION_AUDIO: 65 checks, 0 failures','APP_TESTS: 99 checks, 0 failures','Rewind: 61 checks, 0 failures','SCRIPT_PARSE: 418 scripts, 0 failures']:
    choices=[p for p in logfiles if marker in p.read_text(encoding='utf-8',errors='replace')]
    assert choices,marker
    selected.append(max(choices,key=lambda p:p.stat().st_mtime))
for marker in ['SHARED_COLLISION_AUDIO: ','SHARED_BODY_CONTROLS: ','DIRECT_HIT_BODY_AUDIO: 5 checks, 1 failures']:
    selected.extend(p for p in logfiles if marker in p.read_text(encoding='utf-8',errors='replace'))
for source in set(selected): shutil.copy2(source,logs/(source.parent.name+'-'+source.name))

# Preserve a simple listening artifact from the actual paired captures. Each
# trial retains a 200ms pre-request window; no synthetic audio is mixed in.
import csv
for variant in ['before','after']:
    folder=scratch/variant
    events=json.loads((folder/'events.json').read_text())
    event=next(e for e in events if e['clip']=='chassis')
    with (folder/'packets.csv').open() as f: packets=list(csv.DictReader(f))
    packet=next(p for p in packets if float(p['utc_us'])<=event['unix_us']<float(p['utc_us'])+int(p['frames'])/48000*1e6)
    index=int(packet['frame_offset'])+round((event['unix_us']-float(packet['utc_us']))/1e6*48000)
    audio=np.frombuffer((folder/'loopback.pcm').read_bytes(),dtype='<i2').reshape(-1,2)
    segment=audio[index-9600:index+38400]
    with wave.open(str(OUT/('chassis-'+variant+'.wav')),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(48000);f.writeframes(segment.tobytes())
(OUT/'audition.html').write_text('<!doctype html><meta charset="utf-8"><title>Shared body audio timing</title><style>body{font:17px sans-serif;background:#111b28;color:#eef1f5;margin:32px}audio{display:block;margin:20px 0}</style><p>Actual Windows chassis/body output. Both clips begin 200ms before the request. This is a software capture, not speaker/Bluetooth acoustic timing.</p><p>Before: 146ms median</p><audio controls src="chassis-before.wav"></audio><p>After: 36ms median</p><audio controls src="chassis-after.wav"></audio>',encoding='utf-8')

paths=['DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','docs/SHARED_BODY_AUDIO_TIMING.md','licenses/ASSETS.md','native/windows_audio/impact.cpp','scripts/build_windows_audio.ps1','game/platform/windows/impact.gdextension','game/platform/windows/.gitignore','game/platform/windows/NOTICE.txt','game/platform/windows/bmt_windows_audio_v3.dll','game/platform/windows_impact_audio.gd','game/vehicle/vehicle_audio.gd','game/tests/test_windows_impact_audio.gd','scripts/review_shared_body_audio.py']
for stem in ['probe_shared_collision_audio','capture_shared_body_controls','test_direct_hit_body_audio']:
    paths.extend(['game/tests/'+stem+'.gd','game/tests/'+stem+'.gd.uid'])
review=ROOT/'build/shared-body-review';before=review/'before';after=review/'after'
before.mkdir(parents=True,exist_ok=True);after.mkdir(parents=True,exist_ok=True)
hashes=[]
for relative in paths:
    source=ROOT/relative;old=OUT/'before'/relative
    assert source.exists(),relative
    target=after/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    if old.exists():
        target=before/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(old,target)
    hashes.append(dict(file=relative,bytes=source.stat().st_size,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),before_sha256=hashlib.sha256(old.read_bytes()).hexdigest() if old.exists() else None))
diff=subprocess.run(['git','diff','--no-index','--binary','--','build/shared-body-review/before','build/shared-body-review/after'],cwd=ROOT,capture_output=True)
assert diff.returncode==1,diff.stderr.decode()
patch=diff.stdout
for stage in ['before','after']:
    patch=patch.replace(('a/build/shared-body-review/'+stage+'/').encode(),b'a/').replace(('b/build/shared-body-review/'+stage+'/').encode(),b'b/')
(OUT/'scoped-change.patch').write_bytes(patch)
check=subprocess.run(['git','apply','--reverse','--check',str(OUT/'scoped-change.patch')],cwd=ROOT,capture_output=True)
(OUT/'patch-check.txt').write_text('reverse_check_exit='+str(check.returncode)+'\n'+check.stderr.decode(errors='replace'),encoding='utf-8')
assert check.returncode==0,check.stderr.decode()
(OUT/'source-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8')
bank=ROOT/'game/assets/audio/vehicles'
manifest=json.loads((bank/'manifest.json').read_text())
for row in manifest['outputs']: assert hashlib.sha256((bank/row['file']).read_bytes()).hexdigest()==row['sha256'],row['file']
report=dict(scoped_files=len(paths),logs=len(set(selected)),reverse_check=0,unchanged_vehicle_wavs=len(manifest['outputs']),capture_controls=11,real_time_direct_checks=30,acoustic_measurement=False)
(OUT/'checkpoint-review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
