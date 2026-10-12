"""Original sports-rock rewrite: recorded instruments, amp/cab articulation,
short rhythmic cells and restrained atmospheric support. No runtime synthesis.
"""
from pathlib import Path
from functools import lru_cache
import hashlib
import json
import math
import os
import shutil

import numpy as np
from scipy.signal import butter, sosfilt
import soundfile as sf
import render_locked_in as band

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'build/music/sports-rock-2026-10-08'
MASTERS=WORK/'masters'
EXPORT=WORK/'exports'
EVIDENCE=ROOT/'docs/evidence/sports-rock-2026-10-08'
RATE=band.RATE
BPM=144
MOTIF=band.MOTIF
LAYERS=band.LAYERS
BIOMES=band.BIOMES


@lru_cache(maxsize=900)
def performance(kind,pitch,frames,variation,strong):
    original='guitar' if kind in ['muted','driven','chorus'] else kind
    pcm=band.performed(original,pitch,frames,variation,strong).copy()
    if kind in ['muted','driven','chorus']:
        pcm=sosfilt(butter(2,90,'highpass',fs=RATE,output='sos'),pcm,axis=0)
        drive=6.5 if kind!='chorus' else 4.8
        pcm=np.tanh(pcm*drive)/3.0
        # Offline amp/cab voicing: controlled top end, clearer pick/presence region.
        presence=sosfilt(butter(2,[1700,3300],'bandpass',fs=RATE,output='sos'),pcm,axis=0)
        pcm=sosfilt(butter(2,5700,'lowpass',fs=RATE,output='sos'),pcm+presence*.20,axis=0)
        if kind=='muted':
            t=np.arange(len(pcm))/RATE
            pcm*=np.exp(-np.maximum(0,t-.022)*17)[:,None]
        if kind=='chorus':
            # Two circularly independent takes/positions elsewhere supply width;
            # this subtle baked delay gives the sustained guitar an 80s chorus colour.
            delay=round(RATE*.014)
            delayed=np.zeros_like(pcm);delayed[delay:]=pcm[:-delay,::-1]
            pcm=pcm*.82+delayed*.18
    if kind=='snare_room':
        t=np.arange(len(pcm))/RATE
        gate=1-np.clip((t-.13)/.08,0,1)
        pcm*=gate[:,None]
    return pcm


class RockCells(band.Cells):
    def hit(self,layer,kind,pitch,beat,duration,gain,pan=0,strong=False):
        index=len(self.events)
        timing=math.sin(index*1.71)*(.002 if self.biome=='night_city' else .0045)
        if kind in ['snare','snare_room']:timing+=.003
        start=round((beat*60/self.bpm+timing)*RATE)%self.frames
        sample=performance(kind,pitch,round(duration*60/self.bpm*RATE),index%4,strong)
        sample=sample*gain*(1+.05*math.sin(index*.73))
        sample*=np.array([math.sqrt((1-pan)/2),math.sqrt((1+pan)/2)])
        count=min(len(sample),self.frames-start)
        self.parts[layer][start:start+count]+=sample[:count]
        if count<len(sample):self.parts[layer][:len(sample)-count]+=sample[count:]
        self.events.append({'layer':LAYERS[layer],'instrument':kind,'midi':pitch,'beat':beat,'length':duration,'gain':gain,'timing_offset':timing})


# D / C / G / A power harmony, opening out to suspended/ninth colour under the
# same four-note identity. This changes the old rounded major-band composition.
HARMONY=[(38,[50,57,62]),(36,[48,55,60]),(43,[55,62,67]),(45,[57,64,69])]


def atmosphere(score,layer,root,beat,seconds,gain):
    # Original offline analog-style pad. No PCM synth or API runs in the game.
    frames=round(seconds*RATE);t=np.arange(frames)/RATE
    pcm=np.zeros((frames,2))
    for note in [root+12,root+19]:
        f=440*2**((note-69)/12)
        for channel,detune in enumerate([-.0025,.0025]):
            phase=2*np.pi*f*(1+detune)*t
            pcm[:,channel]+=np.sin(phase)*.75+np.sin(phase*2)*.10+np.sin(phase*3)*.055
    env=np.sin(np.linspace(0,np.pi,frames))**2
    pcm*=env[:,None]*gain
    start=round(beat*60/score.bpm*RATE)%score.frames;count=min(frames,score.frames-start)
    score.parts[layer][start:start+count]+=pcm[:count]
    if count<frames:score.parts[layer][:frames-count]+=pcm[count:]
    score.events.append({'layer':LAYERS[layer],'instrument':'original atmospheric pad','midi':root+12,'beat':beat,'seconds':seconds,'gain':gain})


def compose(biome):
    score=RockCells(biome)
    for bar in range(32):
        at=bar*4;root,chord=HARMONY[bar%4]
        # The opening has purposeful forward motion, with deliberate holes that
        # earned parts fill; no loud complete band at the starting line.
        for beat,gain in [(0,.34),(1,.26),(2.5,.31)]:score.hit(0,'bass',root,at+beat,.45,gain,0,True)
        for beat,pitch,gain in [(0,chord[0],.22),(.5,chord[0],.15),(2,chord[1],.20),(2.75,chord[0],.16)]:
            score.hit(0,'muted',pitch,at+beat,.32,gain,-.12,True)
        score.hit(0,'kick',60,at,.28,.13,0,True)
        for beat in [1,3]:score.hit(0,'hat',60,at+beat,.17,.055,.10)
        if bar%4==0:
            score.hit(0,'driven',MOTIF[0]-12,at+1.5,.45,.11,.14,True)
            score.hit(0,'driven',MOTIF[1]-12,at+3.5,.4,.09,.14,True)
        # Coherence joins riff/bass gaps, with a small atmospheric harmonic horizon.
        for beat in [.75,1.75,3,3.5]:score.hit(1,'bass',root+(7 if beat==3.5 else 0),at+beat,.38,.23,0,True)
        for beat in [1.25,1.75,3.25,3.5]:score.hit(1,'muted',chord[0],at+beat,.3,.16,.16,True)
        if bar%2==0:
            atmosphere(score,1,root,at,3.0,.006 if biome!='winter' else .009)
        # Firm 80s backbeat, short gated room, restrained live tom answers.
        for beat,gain in [(.5,.18),(1.75,.24),(2,.31),(2.75,.18)]:score.hit(2,'kick',60,at+beat,.29,gain,0,True)
        for beat in [1,3]:
            score.hit(2,'snare',60,at+beat,.38,.29,-.04,True)
            score.hit(2,'snare_room',60,at+beat,.45,.15,.08,True)
        for eighth in range(8):
            if bar%4==3 and eighth>=6:continue
            score.hit(2,'hat',60,at+eighth*.5,.16,.115 if eighth%2==0 else .075,.10,eighth%2==0)
        if bar%4==3:
            for beat,gain in [(3,.10),(3.25,.13),(3.5,.17)]:score.hit(2,'tom',60,at+beat,.28,gain,.16,True)
            score.hit(2,'hat_open',60,at+3.75,.25,.075,.12)
        if bar%8==0:score.hit(2,'crash',60,at,.75,.10,.2)
        # Recompose the motif into a repeated riff and a different answer, with
        # silence separating statements; no solo that competes with steering.
        if bar%2==0:
            for beat,pitch,length in zip([0,.5,1.75,2.5],MOTIF,[.38,.6,.6,.75]):
                score.hit(3,'driven',pitch,at+beat,length,.27,-.06,True)
            score.hit(3,'driven',MOTIF[1],at+3.5,.3,.12,.10,True)
        else:
            for beat,pitch in [(1.5,MOTIF[2]),(2.25,MOTIF[3]),(3.25,MOTIF[0])]:score.hit(3,'driven',pitch,at+beat,.55,.19,.12,True)
        # Atmospheric growth is an answering string/synth texture under the rock.
        for side in [-1,1]:
            for beat in [.25,2.25]:
                for n,pitch in enumerate(chord[:2]):score.hit(4,'chorus',pitch,at+beat+n*.022,1.5,.13,side*.68,True)
        if bar%4==0:
            score.hit(4,'violin',MOTIF[3],at+1,3.2,.08,-.18)
            atmosphere(score,4,root,at+1,2.5,.007)
        if biome=='winter' and bar%4==2:score.hit(4,'piano',MOTIF[2],at+2,1.2,.075,.15)
        # Reserved payoff broadens the known riff instead of becoming a guitar solo.
        if bar%4 in [0,2]:
            for beat,pitch in zip([0,.5,1.75,2.5],MOTIF):score.hit(5,'driven',pitch+12,at+beat,.85,.18,.12,True)
            score.hit(5,'violin',MOTIF[3]+12,at+3,3.0,.065,-.12)
    return score


def palette(pcm,layer,biome):
    out=band.palette(pcm,layer,biome)
    # Restrained baked chamber reflections keep texture behind direct rock attacks.
    if layer in [1,4,5]:
        wet=np.zeros_like(out)
        for i in range(16):wet+=np.roll(out[:,::-1],round(RATE*(.047+i*.062)),axis=0)*.018*math.exp(-i/8)
        out+=wet
    return out


def menu():
    score=RockCells('pine',bpm=112,bars=16)
    for bar in range(16):
        at=bar*4;root,chord=HARMONY[bar%4]
        score.hit(0,'bass',root,at,.9,.14,0,True)
        for beat in [0,2.5]:score.hit(0,'muted',chord[0],at+beat,.4,.11,-.1,True)
        for beat in [1,3]:score.hit(0,'hat',60,at+beat,.2,.035,.10)
        if bar%2==0:
            for beat,pitch in zip([0,.5,1.75,2.5],MOTIF):score.hit(0,'chorus',pitch-12,at+beat,.85,.13,.1,True)
            atmosphere(score,0,root,at,2.3,.008)
        else:
            score.hit(0,'violin',MOTIF[3]-12,at+.5,2.7,.05,-.14)
    return palette(score.parts[0],4,'pine')


def event(pb=False,breath=False):
    score=RockCells('pine',bars=2)
    if breath:
        score.hit(0,'chorus',62,0,2,.09,0,True)
        pcm=score.parts[0][:round(RATE*1.25)]
        pcm[-round(RATE*.1):]*=np.linspace(1,0,round(RATE*.1))[:,None]**2
        return pcm
    for n,pitch in enumerate(MOTIF+[74 if pb else 62]):score.hit(0,'driven',pitch,n*.5,.6,.19 if pb else .13,-.05,True)
    for n,pitch in enumerate([50,57,66]):score.hit(0,'chorus',pitch,2+n*.02,2,.11 if pb else .07,.18,True)
    if pb:score.hit(0,'crash',60,2,.7,.08,.15)
    pcm=palette(score.parts[0],4,'pine');pcm[-round(RATE*.3):]*=np.linspace(1,0,round(RATE*.3))[:,None]**2
    return pcm


def main():
    if (MASTERS/'manifest.json').exists():raise ValueError('Preserve source renders; use a new revision directory')
    MASTERS.mkdir(parents=True,exist_ok=True);EXPORT.mkdir(parents=True,exist_ok=True);EVIDENCE.mkdir(parents=True,exist_ok=True)
    band.chamber.MASTERS=MASTERS;band.chamber.OUTPUT=EXPORT
    band.chamber.FFMPEG=str(Path.home()/'.local/share/bmt-music-tools/ffmpeg')
    outputs=[];packages=[];foley=[]
    for biome in BIOMES:
        cells=compose(biome);foley.append(band.foley(cells,biome))
        parts=[palette(p,i,biome) for i,p in enumerate(cells.parts)]
        full=sum(parts);gain=float(min(.43/np.max(np.abs(full)),.052/max(np.sqrt(np.mean(full**2)),1e-9)))
        for name,part in zip(LAYERS,parts):outputs.append(band.chamber.export_loop(f'{biome}_{name}',part,'additive_runtime_layer',gain))
        band.chamber.write_wav(EVIDENCE/f'{biome}-full.wav',full*gain)
        frames=RATE*90;t=np.arange(frames,dtype=float)/RATE;story=np.zeros((frames,2))
        for i,part in enumerate(parts):
            blend=np.clip((t-[0,6,16,30,44,56][i])/(240/BPM*2),0,1);blend=blend**2*(3-2*blend)
            if i==0:blend=np.ones(frames)
            story+=np.tile(part,(2,1))[:frames]*(blend*gain)[:,None]
        story[:RATE//2]*=np.linspace(0,1,RATE//2)[:,None];story[-RATE:]*=np.linspace(1,0,RATE)[:,None]
        band.chamber.write_wav(EVIDENCE/f'{biome}-clean-story.wav',story)
        packages.append({'id':biome,'bpm':BPM,'bars':32,'frames':2352000,'motif':MOTIF,'layers':[f'{biome}_{n}.ogg' for n in LAYERS],'common_gain':gain,'combined':band.chamber.metrics(full*gain),'events':cells.events})
    pcm=menu();gain=float(min(.25/np.max(np.abs(pcm)),.027/max(np.sqrt(np.mean(pcm**2)),1e-9)))
    outputs.append(band.chamber.export_loop('menu_theme',pcm,'complete_menu_mix',gain));band.chamber.write_wav(EVIDENCE/'menu-theme.wav',pcm*gain)
    for name,pb,breath in [('finish',False,False),('personal_best',True,False),('breath',False,True)]:
        pcm=event(pb,breath);pcm*=min(1,.23/max(np.max(np.abs(pcm)),1e-9))
        out=EXPORT/(name+'.wav');sf.write(out,pcm,RATE,subtype='PCM_16');band.chamber.write_wav(EVIDENCE/(name+'.wav'),pcm)
        outputs.append({'file':out.name,'role':'musical_event','loop':False,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'bytes':out.stat().st_size,'duration_seconds':len(pcm)/RATE})
    for name in ['ui_select.wav','ui_confirm.wav','ui_back.wav']:
        source=ROOT/'game/assets/audio/locked_in_v1'/name;out=EXPORT/name;shutil.copyfile(source,out)
        outputs.append({'file':name,'role':'interface','loop':False,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'bytes':out.stat().st_size})
    prior=json.loads((ROOT/'game/assets/audio/locked_in_v1/manifest.json').read_text())
    m={'schema_version':1,'asset_id':'bmt-sports-rock-2026-10-08','created_on':'2026-10-08','menu_bpm':112,'direction':'80s-rock-energy-with-atmospheric-background-depth','status':'owner_audition','motif_midi':MOTIF,
       'generator':prior['generator'],'score_source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'sampler_source_sha256':hashlib.sha256(Path(band.__file__).read_bytes()).hexdigest(),
       'input_sources':band.SOURCE_MANIFEST,'supporting_sources':prior['supporting_sources'],'packages':packages,'outputs':outputs,'licensing':prior['licensing'],'approval':{'user_approved':False,'scope':[]},
       'changes':['new riff/harmony/phrasing','recorded guitar amp/cab/palm-mute/chorus processing','firm acoustic/gated-room backbeat','original quiet offline analog-style pad and string texture','constant family gain, unchanged runtime/volume contracts']}
    text=json.dumps(m,indent=2)+'\n';(EXPORT/'manifest.json').write_text(text);(MASTERS/'manifest.json').write_text(text)
    shutil.copyfile(Path(__file__),MASTERS/'render_source.py')
    for name in ['NOTICE.txt','CC0-LICENSE.txt']:shutil.copyfile(ROOT/'game/assets/audio/locked_in_v1'/name,EXPORT/name)
    with (EXPORT/'NOTICE.txt').open('a') as f:f.write('\n2026-10-08 sports-rock rewrite: original riff/phrases, offline amp/cab and atmosphere processing; recorded source licences unchanged. No reference-game audio used.\n')
    print('SPORTS_ROCK_RENDER',len(outputs),sum(x['bytes'] for x in outputs),'audio bytes',flush=True)


if __name__=='__main__':main()
