"""One directly written theme study. No AI performance or spectral layering."""
from pathlib import Path
import hashlib,json,math,shutil
import numpy as np
import soundfile as sf
from scipy.signal import butter,sosfilt
import render_locked_in as band

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'build/music/clear-theme-2026-10-08/balanced'
EVIDENCE=ROOT/'docs/evidence/clear-theme-2026-10-08'
RATE=44100;BPM=160

# A complete eight-bar melodic sentence, with repeated gestures and answers.
# Every event is explicit; sections change intentional endings/orchestration.
THEME=[[(0,69,.65),(.75,66,1.1),(2,64,.65),(3,66,.8)],
       [(0,62,1.6),(2,66,.65),(3,69,.8)],
       [(0,71,1.6),(2,69,.65),(3,66,.8)],
       [(0,64,1.1),(1.5,62,2.0)],
       [(0,67,1.1),(1.5,69,.65),(2.5,71,1.1)],
       [(0,69,2.5),(3,66,.8)],
       [(0,69,.65),(1,71,.65),(2,76,1.6)],
       [(0,73,1.1),(1.5,71,.65),(2.5,69,1.1)]]
BRIDGE=[[(0,66,1.6),(2,64,1.5)],[(.5,62,1.1),(2,66,1.5)],
        [(0,67,1.1),(1.5,69,2)],[(0,71,2.5),(3,69,.65)],
        [(0,69,.65),(1,67,.65),(2,66,1.6)],[(0,64,2.5),(3,66,.65)],
        [(0,67,1.1),(1.5,69,1.1),(3,71,.65)],[(0,73,1.6),(2,69,1.6)]]
HARMONY=[(38,[50,54,57,64]),(38,[54,57,62]),(35,[47,54,57,62]),(35,[47,54,57]),
         (31,[43,54,57,62]),(38,[50,54,57]),(33,[45,52,57,62]),(33,[45,52,57,61])]


def colour(pcm,cutoff):
    return sosfilt(butter(2,cutoff,'lowpass',fs=RATE,output='sos'),pcm,axis=0)


def main():
    if (WORK/'manifest.json').exists():raise ValueError('Preserve sketches; choose a fresh revision')
    WORK.mkdir(parents=True,exist_ok=True);EVIDENCE.mkdir(parents=True,exist_ok=True)
    score=band.Cells('pine',bpm=BPM,bars=32)
    for bar in range(32):
        at=bar*4;root,chord=HARMONY[bar%8]
        if bar==31:root,chord=38,[50,54,57,62]
        melody=BRIDGE[bar%8] if 16<=bar<24 else THEME[bar%8]
        if bar==31:melody=[(0,73,.8),(1,71,.65),(2,69,.6),(3,62,1.0)]
        for beat,pitch,length in melody:
            # Piano exposes the exact melody; warm guitar doubles its lower octave.
            score.hit(0,'piano',pitch,at+beat,length,.40,0)
            score.hit(1,'guitar',pitch-12,at+beat+.015,length,.80,-.12,True)
        for beat,pitch,length in [(0,root,.65),(1.5,root+7,.55),(2.5,root,.55),(3.5,root+12,.3)]:
            score.hit(2,'bass',pitch,at+beat,length,.15,0,True)
        # Harmonic support sustains; it never substitutes for the melody.
        for n,pitch in enumerate(chord[1:]):
            score.hit(3,'guitar',pitch,at+.025*n,2.6,.22,.18)
        for beat in [0,2]:score.hit(4,'kick',60,at+beat,.3,.13,0,True)
        for beat in [1,3]:score.hit(4,'snare',60,at+beat,.35,.065,-.05)
        for beat in [0,1,2,3]:score.hit(4,'hat',60,at+beat,.18,.025,.12)
        if bar%8==7:
            for beat,gain in [(3,.04),(3.5,.045)]:score.hit(4,'tom',60,at+beat,.25,gain,.1)
        if bar>=8:
            for beat,pitch,length in melody:
                if length>=1.0:score.hit(5,'violin',pitch,at+beat,length,.045,-.15)
    # Recorded performances follow exact score pitches/durations and common clock.
    parts=[colour(score.parts[0],6000),colour(score.parts[1],4200),
           colour(score.parts[2],2600),colour(score.parts[3],4600),
           colour(score.parts[4],3300),colour(score.parts[5],5700)]
    for layer in [0,1,3,5]:
        pcm=parts[layer];wet=np.zeros_like(pcm)
        for i in range(12):wet+=np.roll(pcm[:,::-1],round(RATE*(.043+.061*i)),axis=0)*.018*math.exp(-i/4)
        parts[layer]=pcm+wet
    # Source libraries have very different recording levels. Balance complete
    # roles with one gain each, preserving expression within each performance.
    role_targets=[.055,.018,.027,.018,.015,.009]
    role_gains=[]
    for i,part in enumerate(parts):
        level=float(np.sqrt(np.mean(part**2)))
        role_gain=role_targets[i]/max(level,1e-10)
        parts[i]=part*role_gain;role_gains.append(role_gain)
    mix=sum(parts);gain=min(.38/np.max(np.abs(mix)),.045/np.sqrt(np.mean(mix**2)))
    mix*=gain
    # This is a finite musical sketch; no claimed production loop/adaptive bank.
    fade=round(RATE*.4);mix[-fade:]*=np.cos(np.linspace(0,np.pi/2,fade))[:,None]**2
    mix[:round(RATE*.02)]*=np.linspace(0,1,round(RATE*.02))[:,None]
    sf.write(EVIDENCE/'complete-theme-v3.wav',mix,RATE,subtype='PCM_24')
    melody=parts[0]*gain;melody[-fade:]*=np.cos(np.linspace(0,np.pi/2,fade))[:,None]**2
    sf.write(EVIDENCE/'melody-only-v3.wav',melody,RATE,subtype='PCM_24')
    manifest={'schema_version':1,'asset_id':'clear-theme-study-2026-10-08','status':'unreviewed_sketch',
        'bpm':BPM,'bars':32,'frames':len(mix),'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'composition':'explicit eight-bar statement/answer, variation, bridge and return; complete melody present from start',
        'events':score.events,'inputs':band.SOURCE_MANIFEST,'supporting_library':'VSCO2 CE CC0, prior pinned source recordings',
        'approval':{'user_approved':False,'scope':[]},'no_ai_performance':True,'no_spectral_split':True,
        'role_gains':role_gains,'role_target_rms':role_targets,
        'output':{'file':'complete-theme-v3.wav','sha256':hashlib.sha256((EVIDENCE/'complete-theme-v3.wav').read_bytes()).hexdigest(),
                  'peak_dbfs':float(20*np.log10(np.max(np.abs(mix)))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(mix**2))))}}
    (WORK/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copyfile(Path(__file__),WORK/'composer.py')
    sf.write(WORK/'complete-master.wav',mix,RATE,subtype='PCM_24')
    print('CLEAR_THEME_SKETCH',len(mix)/RATE,'seconds; explicit melody, original recorded-source arrangement; owner audition only')


if __name__=='__main__':main()
