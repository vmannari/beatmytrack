"""Focused 144 BPM Desert-loop repair; preserve the original tempo render."""
from pathlib import Path
import hashlib
import json
import shutil
import numpy as np
import render_locked_in as score

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/music/locked-in-v1/tremolo-repair'
BANK=ROOT/'game/assets/audio/locked_in_v1'
EVIDENCE=ROOT/'docs/evidence/locked-in-score-2026-10-07/mix4'


def main():
    if (OUT/'repair.json').exists():raise ValueError('Preserve the repair; use a new revision for further edits')
    OUT.mkdir(parents=True,exist_ok=True)
    old=json.loads((BANK/'manifest.json').read_text())
    cells=score.compose('desert');score.foley(cells,'desert')
    parts=[score.palette(part,i,'desert') for i,part in enumerate(cells.parts)]
    full=sum(parts);gain=float(min(.48/np.max(np.abs(full)),.060/max(np.sqrt(np.mean(full**2)),1e-9)))
    score.chamber.MASTERS=OUT/'masters';score.chamber.MASTERS.mkdir(exist_ok=True)
    score.chamber.OUTPUT=OUT
    score.chamber.FFMPEG=str(Path.home()/'.local/share/bmt-music-tools/ffmpeg')
    outputs=[]
    for label,part in zip(score.LAYERS,parts):
        outputs.append(score.chamber.export_loop('desert_'+label,part,'additive_runtime_layer',gain))
        shutil.copyfile(OUT/('desert_'+label+'.ogg'),BANK/('desert_'+label+'.ogg'))
    for item in outputs:
        for index,existing in enumerate(old['outputs']):
            if existing['file']==item['file']:old['outputs'][index]=item
    for package in old['packages']:
        if package['id']=='desert':package['combined']=score.chamber.metrics(full*gain);package['common_gain']=gain
    old['tempo_loop_repair']={'reason':'Tremolo locked to two cycles per beat; arbitrary 5Hz did not tile at 144 BPM','source_sha256':hashlib.sha256(Path(score.__file__).read_bytes()).hexdigest(),'original_master':'build/music/locked-in-v1/masters-mix4','new_master':str((OUT/'masters').relative_to(ROOT))}
    (BANK/'manifest.json').write_text(json.dumps(old,indent=2)+'\n')
    frames=score.RATE*90;t=np.arange(frames,dtype=float)/score.RATE;mix=np.zeros((frames,2))
    for i,part in enumerate(parts):
        weight=np.clip((t-[0,6,16,30,44,56][i])/4,0,1);weight=weight**2*(3-2*weight)
        if i==0:weight=np.ones(frames)
        mix+=np.tile(part,(2,1))[:frames]*(weight*gain)[:,None]
    mix[:score.RATE//2]*=np.linspace(0,1,score.RATE//2)[:,None];mix[-score.RATE:]*=np.linspace(1,0,score.RATE)[:,None]
    for name,pcm in [('desert-full.wav',full*gain),('desert-clean-story.wav',mix)]:
        prior=EVIDENCE/name
        if prior.exists():shutil.copyfile(prior,OUT/('before-'+name))
        score.chamber.write_wav(prior,pcm)
    (OUT/'repair.json').write_text(json.dumps(old['tempo_loop_repair'],indent=2)+'\n')
    print('DESERT_TREMOLO_REPAIR complete: exact 144 BPM cycles, prior sources preserved')


if __name__=='__main__':main()
