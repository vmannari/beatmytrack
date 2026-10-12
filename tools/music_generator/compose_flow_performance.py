"""New original phrase score, rendered locally with verified MRT2 MIDI controls."""
from pathlib import Path
import hashlib,json,time,uuid,importlib.metadata,fcntl
import numpy as np
import soundfile as sf
import generate as studio

ROOT=Path(__file__).resolve().parents[2]
BPM=160
# Eight-bar harmonic sentence, followed by related departure/return voicings.
HARMONY=[(38,[54,57,61,64]),(38,[54,57,61,64]),(35,[54,57,62]),(35,[54,57,62]),
         (31,[54,57,62]),(40,[55,59,62]),(33,[52,57,59,62]),(33,[52,57,61,64])]
MOTIF=[66,69,71,64]


def score(bars=64):
    events=[]
    def add(beat,pitch,length,role):
        events.append({'beat':beat,'midi':pitch,'length_beats':length,'role':role})
    phrases=[[(.5,66,.75),(1.5,69,1.25),(3,71,.75)],
             [(.5,69,1.25),(2,66,.75),(3.25,64,.65)],
             [(0,66,1.5),(2,69,.75),(3,71,.75)],
             [(.5,73,.75),(1.5,71,1.25),(3,69,.75)],
             [(.5,71,1.25),(2,69,1.5)],
             [(0,67,.75),(1.25,66,1.25),(3,64,.75)],
             [(.5,64,1.25),(2,66,.75),(3,69,.75)],
             [(0,66,1.25),(2,64,1.65)]]
    for bar in range(bars):
        at=bar*4;root,chord=HARMONY[bar%8]
        for pitch in chord:add(at,pitch,3.85,'harmonic_support')
        for beat,length,pitch in [(0,.65,root),(.75,.5,root),(1.5,.75,root+7),(2.75,.6,root),(3.5,.35,root+12)]:
            add(at+beat,pitch,length,'bass')
        for beat,pitch,length in phrases[bar%8]:
            if bar%16>=8 and bar%8 in [2,3]:pitch+=12
            add(at+beat,pitch,length,'theme')
    return events


def main():
    from magenta_rt import MagentaRT2Jax,musiccoca,paths
    from magenta_rt.config import MUSICCOCA,PIANOROLL_WITH_ONSETS,DRUM_PIANOROLL
    assert importlib.metadata.version('magenta-rt')=='2.0.3'
    run=ROOT/'build/music/performed-flow'/('20261008-'+uuid.uuid4().hex[:8])
    run.mkdir(parents=True)
    prompt='160 BPM original bright cinematic sports rock instrumental game underscore. Agile live drums, melodic finger bass, warm electric guitar, flowing chamber strings and spacious piano. Lyrical eight-bar phrases, suspended harmony, anticipation and luminous resolution. Quiet polished background balance, soft cymbals, warm natural attacks. No vocals, chugging riff, piercing solo, EDM or trailer hits.'
    job={'name':'flow_performance','prompt':prompt,'style_seed':0}
    style,embeddings=studio.condition_jobs([job])
    events=score()
    manifest={'schema_version':1,'asset_id':run.name,'approval':'unreviewed','bpm':BPM,'bars':64,
        'motif_midi':MOTIF,'score':events,'style':job,'model':'mrt2_base',
        'versions':{p:importlib.metadata.version(p) for p in ['magenta-rt','jax','jaxlib','numpy','scipy','soundfile']},
        'generator_source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'conditioning':'original per-frame MIDI pitch activity/onsets and drum pulse, streamed with retained model state',
        'notes_adherence':'requires measured and listening verification; conditioning alone is not proof',
        'terms':'https://github.com/magenta/magenta-realtime/blob/main/MODEL.md',
        'parameters':{'temperature':1.2,'top_k':40,'cfg_musiccoca':3,'cfg_notes':3,'cfg_drums':1},'status':'loading'}
    studio.atomic_json(run/'manifest.json',manifest)
    model=MagentaRT2Jax(size='mrt2_base',style_model=style,temperature=1.2,top_k=40,
        cfg_scales={'musiccoca':3.0,'notes':3.0,'drums':1.0})
    state=None;chunks=[];started=time.monotonic();frames=2400
    manifest['status']='generating';studio.atomic_json(run/'manifest.json',manifest)
    for frame in range(frames):
        # Model frames are40ms. Quantize every intended musical onset to that
        # existing codec grid; no claimed sample-exact MIDI adherence.
        notes=[0]*128
        for event in events:
            begin=round(event['beat']*60/BPM*25)
            end=round((event['beat']+event['length_beats'])*60/BPM*25)
            if begin<=frame<end:notes[event['midi']]=max(notes[event['midi']],2 if frame==begin else 1)
        beat=frame/25*BPM/60
        next_pulse=round(round(beat*2)/2*60/BPM*25)
        drum=1 if frame==next_pulse else 0
        wav,state=model.generate(conditioning={MUSICCOCA.key:embeddings[0],PIANOROLL_WITH_ONSETS.key:notes,DRUM_PIANOROLL.key:[drum]},frames=1,state=state)
        chunks.append(wav.samples)
        if frame%250==249:print('PERFORMED_FLOW',frame+1,'/',frames,flush=True)
    pcm=np.concatenate(chunks,axis=0)
    path=run/'flow-performance.wav';sf.write(path,pcm,48000,subtype='PCM_24')
    manifest.update(status='complete',file=path.name,metrics=studio.audio_metrics(path),elapsed_seconds=time.monotonic()-started)
    studio.atomic_json(run/'manifest.json',manifest)
    (run/'composer.py').write_bytes(Path(__file__).read_bytes())
    print('PERFORMED_FLOW_COMPLETE',str(run),flush=True)


if __name__=='__main__':
    with (ROOT/'build/music/.generation.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        main()
