"""Render the existing R3 score at six true tempos, without resampling pitches."""
import hashlib
import json
import shutil
import subprocess
import uuid
import wave
from datetime import datetime, timezone
import numpy as np
from additive_bank import ROOT, TOOL, RATE, ROLES, soften_opening

BPMS = [90, 102, 114, 126, 138, 150]

def main():
    source = sorted((ROOT/'build/music/additive').glob('shared-road-r3-*/manifest.json'))[-1]
    original = json.loads(source.read_text(encoding='utf-8'))
    compiler = shutil.which('g++') or 'C:/msys64/mingw64/bin/g++.exe'
    renderer = TOOL/'render_score.exe'
    subprocess.run([compiler,'-O2','-std=c++17','-static','-I',str(TOOL),
                    str(ROOT/'tools/music_generator/render_score.cpp'),'-o',str(renderer)],check=True)
    out = ROOT/'build/music/tempo'/('evolving-r4-'+datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6])
    out.mkdir(parents=True)
    jobs=[]
    bound=0
    for bpm in BPMS:
        samples=[]
        for j in original['jobs']:
            stem=f"{bpm}-{j['state_index']}-{j['variant']}"
            score=out/(stem+'.score'); shutil.copyfile(source.parent/j['score'],score)
            subprocess.run([str(renderer),str(TOOL/'GeneralUser-GS.sf2'),str(score),str(j['bank']),str(j['program']),str(out/(stem+'.f32')),str(bpm)],check=True)
            a=np.fromfile(out/(stem+'.f32'),dtype='<f4').reshape(-1,2)
            if j['state_index']==0: a=soften_opening(a,bpm)
            a*=ROLES[j['state_index']][2]
            assert np.isfinite(a).all() and np.max(np.abs(a))>.001
            samples.append(a)
            jobs.append({**j,'family':'evolving_r4','file':stem+'.wav','score':score.name,'bpm':bpm,
                         'source_asset':(source.parent/j['file']).relative_to(ROOT/'build/music').as_posix(),
                         'alignment':f'{bpm} BPM · same R3 score · 32 beats · original pitch',
                         'score_sha256':hashlib.sha256(score.read_bytes()).hexdigest()})
        groups=[np.stack(samples[i:i+3]) for i in range(0,18,3)]
        upper=sum(np.maximum(0,g.max(axis=0)) for g in groups)
        lower=sum(np.minimum(0,g.min(axis=0)) for g in groups)
        bound=max(bound,float(upper.max()),float(-lower.min()))
        print(bpm,'BPM rendered',flush=True)
    gain=.68/bound
    for j in jobs:
        a=np.fromfile(out/j['file'].replace('.wav','.f32'),dtype='<f4').reshape(-1,2)*ROLES[j['state_index']][2]*gain
        pcm=np.rint(a*32767).astype('<i2')
        with wave.open(str(out/j['file']),'wb') as f:
            f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
        j['sha256']=hashlib.sha256((out/j['file']).read_bytes()).hexdigest()
        j['metrics']={'duration':len(a)/RATE,'frames':len(a),'sample_rate':RATE,'channels':2,
                      'peak':float(np.max(np.abs(a))),'loop_boundary_delta':float(np.max(np.abs(a[0]-a[-1])))}
    manifest={**original,'asset_id':out.name,'jobs':jobs,'tempo_stages':BPMS,
              'generator':{**original['generator'],'command_or_entrypoint':'python tools/music_generator/tempo_bank.py'},
              'source_manifest':str(source.relative_to(ROOT)),
              'mix':{'common_gain':gain,'all_subsets_sample_peak_bound':.68+6/32767},
              'tests':{'all_108_finite_nonzero':'PASS'},'approval':'unreviewed'}
    for name in ('TinySoundFont.LICENSE','GeneralUser.LICENSE'):
        shutil.copyfile(source.parent/name,out/name)
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    evidence=ROOT/'docs/evidence/music-r4';evidence.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(out/'manifest.json',evidence/'generation-manifest.json')
    print(out)

if __name__=='__main__':main()
