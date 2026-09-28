"""R5 focused revision: replace only the rejected opening in fixed/tempo banks."""
from datetime import datetime, timezone
import hashlib
import json
import shutil
import subprocess
import uuid
import wave
import numpy as np
from additive_bank import ROOT, TOOL, RATE, notes, validate_score, soften_opening

def read_audio(path):
    with wave.open(str(path)) as f:
        return np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float32).reshape(-1,2)/32768


def main():
    validate_score()
    fixed_source=sorted(p for p in (ROOT/'build/music/additive').glob('shared-road-r3-*/manifest.json') if not json.loads(p.read_text(encoding='utf-8')).get('opening_revision'))[-1]
    tempo_source=sorted(p for p in (ROOT/'build/music/tempo').glob('evolving-r4-*/manifest.json') if not json.loads(p.read_text(encoding='utf-8')).get('opening_revision'))[-1]
    compiler=shutil.which('g++') or 'C:/msys64/mingw64/bin/g++.exe'
    renderer=TOOL/'render_score.exe'
    subprocess.run([compiler,'-O2','-std=c++17','-static','-I',str(TOOL),str(ROOT/'tools/music_generator/render_score.cpp'),'-o',str(renderer)],check=True)
    suffix=datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6]+'-r5'
    evidence=ROOT/'docs/evidence/music-r5';evidence.mkdir(parents=True,exist_ok=True)
    fixed_out=None
    for source,category,prefix in [(fixed_source,'additive','shared-road-r3-'),(tempo_source,'tempo','evolving-r4-')]:
        m=json.loads(source.read_text(encoding='utf-8'))
        out=ROOT/'build/music'/category/(prefix+suffix);out.mkdir(parents=True)
        if category=='additive':fixed_out=out
        jobs=[];rendered=[]
        for old in m['jobs']:
            j=dict(old);bpm=j.get('bpm',120)
            if j['state_index']==0:
                stem=(f'{bpm}-0-' if category=='tempo' else '01-low-cello-')+str(j['variant'])
                j.update(name=f'Low cello · {"ABC"[j["variant"]-1]}',file=stem+'.wav',score=stem+'.score',program=42,
                         prompt='Four low sustained cello tones, D3-A3, slow softened attacks; replaces rejected short high acoustic motif.')
                score=notes(0,j['variant']-1)
                (out/j['score']).write_text('\n'.join(' '.join(map(str,e)) for e in score))
                subprocess.run([str(renderer),str(TOOL/'GeneralUser-GS.sf2'),str(out/j['score']),'0','42',str(out/(stem+'.f32')),str(bpm)],check=True)
                a=soften_opening(np.fromfile(out/(stem+'.f32'),dtype='<f4').reshape(-1,2),bpm)
                rendered.append((j,a))
            else:
                # The sustained opening fills gaps that were previously silent.
                # Reserve headroom without changing accompaniment notes or balance.
                a=read_audio(source.parent/j['file'])*.85
                with wave.open(str(out/j['file']),'wb') as f:
                    f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(np.rint(a*32767).astype('<i2').tobytes())
                j['sha256']=hashlib.sha256((out/j['file']).read_bytes()).hexdigest()
                j['metrics']={**j['metrics'],'peak':float(np.max(np.abs(a))),'rms':float(np.sqrt(np.mean(a*a))),
                              'loop_boundary_delta':float(np.max(np.abs(a[0]-a[-1])))}
                shutil.copyfile(source.parent/j['score'],out/j['score'])
            j['opening_revision']='low_hold_r5'
            if category=='tempo':
                fixed_name=f'01-low-cello-{j["variant"]}.wav' if j['state_index']==0 else next(x['file'] for x in fixed_jobs if x['state_index']==j['state_index'] and x['variant']==j['variant'])
                j['source_asset']=(fixed_out/fixed_name).relative_to(ROOT/'build/music').as_posix()
            j['score_sha256']=hashlib.sha256((out/j['score']).read_bytes()).hexdigest()
            jobs.append(j)
        # One gain for all new opening alternatives/tempos, no normalization of other parts.
        gain=min(.035/max(np.sqrt(np.mean(a*a)) for _,a in rendered), .13/max(np.max(np.abs(a)) for _,a in rendered))
        backing_peak=0
        for bpm in sorted({j.get('bpm',120) for j in jobs}):
            backing=[read_audio(out/j['file']) for j in jobs if j.get('bpm',120)==bpm and j['state_index']!=0]
            groups=[np.stack(backing[i:i+3]) for i in range(0,15,3)]
            backing_peak=max(backing_peak,float(sum(np.maximum(0,g.max(axis=0)) for g in groups).max()),float(-sum(np.minimum(0,g.min(axis=0)) for g in groups).min()))
        gain=min(gain,(.68-backing_peak)/max(np.max(np.abs(a)) for _,a in rendered))
        assert gain>0
        for j,a in rendered:
            a*=gain;pcm=np.rint(a*32767).astype('<i2')
            with wave.open(str(out/j['file']),'wb') as f:
                f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
            j['sha256']=hashlib.sha256((out/j['file']).read_bytes()).hexdigest()
            j['metrics']={'duration':len(a)/RATE,'frames':len(a),'sample_rate':RATE,'channels':2,'peak':float(np.max(np.abs(a))),
                          'rms':float(np.sqrt(np.mean(a*a))),'loop_boundary_delta':float(np.max(np.abs(a[0]-a[-1])))}
        bounds=[]
        for bpm in sorted({j.get('bpm',120) for j in jobs}):
            arrays=[read_audio(out/j['file']) for j in jobs if j.get('bpm',120)==bpm]
            groups=[np.stack(arrays[i:i+3]) for i in range(0,18,3)]
            bounds.append(max(float(sum(np.maximum(0,g.max(axis=0)) for g in groups).max()),float(-sum(np.minimum(0,g.min(axis=0)) for g in groups).min())))
        assert max(bounds)<.681, bounds
        m.update(jobs=jobs,asset_id=out.name,opening_revision='low_hold_r5',approval='unreviewed',
                 revised_from=str(source.relative_to(ROOT)),
                 generator={**m['generator'],'command_or_entrypoint':'python tools/music_generator/refine_opening.py'},
                 tests={'new_opening_finite_and_mix_headroom':'PASS'},
                 mix={'opening_common_gain':float(gain),'other_parts':'same source performances, shared 0.85 gain for sustained-opening headroom',
                      'all_subsets_sample_peak_bound':max(bounds)},
                 opening={'program':42,'note_range':[50,57],'notes_per_phrase':4,'gate_beats':6.8,
                          'attack_seconds':.25,'fade_out_seconds':.4,'lowpass_hz':1400})
        if category=='tempo':m['source_manifest']=str((fixed_out/'manifest.json').relative_to(ROOT))
        for name in ('TinySoundFont.LICENSE','GeneralUser.LICENSE'):shutil.copyfile(source.parent/name,out/name)
        (out/'manifest.json').write_text(json.dumps(m,indent=2),encoding='utf-8')
        shutil.copyfile(out/'manifest.json',evidence/(category+'-manifest.json'))
        if category=='additive':fixed_jobs=jobs
        print(out,flush=True)

if __name__=='__main__':main()
