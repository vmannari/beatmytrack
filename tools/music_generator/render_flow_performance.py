"""Prepare one performed original score as complementary adaptive components.

These are spectral/rhythmic derivatives of ONE performance, not instrument stems.
No independently generated compositions are layered together.
"""
from pathlib import Path
import hashlib,json,math,shutil,subprocess
import numpy as np
import scipy
from scipy.ndimage import median_filter
from scipy.signal import resample_poly
import librosa
import soundfile as sf
import render_locked_in as band
import render_sports_rock as old
import compose_flow_performance as composer

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'build/music/flow-recompose-2026-10-08'
MASTER=WORK/'masters';EXPORT=WORK/'exports'
EVIDENCE=ROOT/'docs/evidence/flow-recompose-2026-10-08'
RATE=44100;BPM=160;FRAMES=2116800


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def smooth(x,a,b):
    t=np.clip((x-a)/(b-a),0,1)
    return t*t*(3-2*t)


def cyclic_extract(pcm,start,frames,width=2205):
    # Crossfade aligned PRE/POST context around the seam while preserving the
    # complete beat count. No shortening the loop or fading it to silence.
    out=pcm[start:start+frames].copy()
    outgoing=pcm[start+frames-width:start+frames+width]
    incoming=pcm[start-width:start+width]
    t=smooth(np.arange(width*2),0,width*2-1)[:,None]
    blend=outgoing*(1-t)+incoming*t
    out[-width:]=blend[:width];out[:width]=blend[width:]
    return out


def decompose(pcm):
    spectra=np.stack([librosa.stft(pcm[:,ch],n_fft=2048,hop_length=512) for ch in range(2)])
    mag=np.mean(np.abs(spectra),axis=0)
    h=median_filter(mag,size=(1,31));p=median_filter(mag,size=(31,1))
    hm=h*h/(h*h+p*p+1e-15)
    sustained=np.clip(median_filter(mag,size=(1,51))/np.maximum(mag,1e-8),0,1)
    frequency=librosa.fft_frequencies(sr=RATE,n_fft=2048)[:,None]
    bass=1-smooth(frequency,180,340)
    warm=(1-bass)*(1-smooth(frequency,750,1500));upper=1-bass-warm
    percussion_low=.10*(1-smooth(frequency,100,200))
    percussion_detail=.07*(1-smooth(frequency,650,1100))
    masks=[hm*bass+(1-hm)*percussion_low,
        hm*warm*(1-.5*sustained)+(1-hm)*percussion_detail,
        (1-hm)*(1-percussion_low-percussion_detail),
        hm*upper*(1-.6*sustained),
        hm*(.5*warm+.3*upper)*sustained,
        hm*.3*upper*sustained]
    assert np.max(np.abs(sum(masks)-1))<1e-10
    parts=[np.stack([librosa.istft(spectra[ch]*mask,hop_length=512,length=len(pcm)) for ch in range(2)],axis=1) for mask in masks]
    error=float(np.max(np.abs(sum(parts)-pcm)))
    assert error<1e-8,'Complementary components must reconstruct the same performance'
    # STFT edges have incomplete periodic context. Smooth the component seams
    # together with a Hermite correction over8ms; this is tiny versus phrasing.
    width=round(RATE*.008)
    for part in parts:
        jump=part[0]-part[-1]
        taper=smooth(np.arange(width),0,width-1)[:,None]
        part[-width:]+=jump*taper
    return parts,error


def main():
    if (MASTER/'manifest.json').exists():raise ValueError('Preserve masters; use a new revision directory')
    run=ROOT/'build/music/performed-flow/20261008-85708a26'
    source_manifest=json.loads((run/'manifest.json').read_text())
    assert source_manifest['status']=='complete'
    path=run/source_manifest['file'];pcm,rate=sf.read(path,always_2d=True)
    assert len(pcm)==4608000 and rate==48000
    # The complete preserved take has three near-full-scale samples during its
    # opening warm-up. The game uses a later clean region, never those samples.
    analysis=json.loads((WORK/'performance-analysis.json').read_text())
    beats=np.asarray(analysis['beats'])
    native_bpm=60/np.polyfit(np.arange(len(beats[10:-10])),beats[10:-10],1)[0]
    ratio=BPM/native_bpm
    ffmpeg=str(Path.home()/'.local/share/bmt-music-tools/ffmpeg')
    retimed=WORK/'retimed-performance.wav'
    subprocess.run([ffmpeg,'-nostdin','-y','-hide_banner','-loglevel','error','-i',str(path),'-af',f'atempo={ratio:.10f}','-c:a','pcm_f32le',str(retimed)],check=True)
    pcm,rate=sf.read(retimed,always_2d=True)
    pcm=resample_poly(pcm,147,160,axis=0)
    # Eight measured musical bars of warm-up, then32 bars of one performance.
    start=12*RATE
    used=pcm[start-2205:start+FRAMES+2205]
    assert np.count_nonzero(np.abs(used)>=.999)==0,'Reject near-full-scale source material used by the game'
    cue=cyclic_extract(pcm,start,FRAMES)
    mid=cue.mean(axis=1,keepdims=True);cue=mid+(cue-mid)*.45
    cue-=cue.mean(axis=0)
    parts,error=decompose(cue)
    for folder in [MASTER,EXPORT,EVIDENCE]:folder.mkdir(parents=True,exist_ok=True)
    band.BPM=BPM;band.chamber.MASTERS=MASTER;band.chamber.OUTPUT=EXPORT
    band.chamber.FFMPEG=str(Path.home()/'.local/share/bmt-music-tools/ffmpeg')
    outputs=[];packages=[]
    for biome in band.BIOMES:
        coloured=[band.palette(part,i,biome) for i,part in enumerate(parts)]
        full=sum(coloured);gain=min(.40/np.max(np.abs(full)),.052/np.sqrt(np.mean(full**2)))
        for layer,part in zip(band.LAYERS,coloured):outputs.append(band.chamber.export_loop(f'{biome}_{layer}',part,'complementary_performance_component',gain))
        band.chamber.write_wav(EVIDENCE/(biome+'-full.wav'),full*gain)
        frames=RATE*90;t=np.arange(frames)/RATE;story=np.zeros((frames,2))
        for i,part in enumerate(coloured):
            blend=smooth(t,[0,6,16,30,44,56][i],[0,6,16,30,44,56][i]+3)
            if i==0:blend=np.ones(frames)
            story+=np.tile(part,(2,1))[:frames]*(blend*gain)[:,None]
        story[:RATE//2]*=np.linspace(0,1,RATE//2)[:,None];story[-RATE:]*=np.linspace(1,0,RATE)[:,None]
        band.chamber.write_wav(EVIDENCE/(biome+'-clean-story.wav'),story)
        packages.append({'id':biome,'bpm':BPM,'bars':32,'frames':FRAMES,'motif':composer.MOTIF,'layers':[f'{biome}_{n}.ogg' for n in band.LAYERS],'common_gain':float(gain),'combined':band.chamber.metrics(full*gain)})
    # Dedicated calm menu arrangement from the same actual theme/performance.
    # Removing the separated rhythmic component avoids the rejected hat ticks.
    harmonic=parts[0]+parts[1]+parts[3]+parts[4]+parts[5]
    menu_input=WORK/'menu-input.wav';sf.write(menu_input,harmonic,RATE,subtype='FLOAT')
    stretched=WORK/'menu-stretched.wav'
    subprocess.run([band.chamber.FFMPEG,'-nostdin','-y','-hide_banner','-loglevel','error','-i',str(menu_input),'-af','atempo=0.7','-c:a','pcm_f32le',str(stretched)],check=True)
    menu_long,menu_rate=sf.read(stretched,always_2d=True)
    menu_frames=1512000
    menu=cyclic_extract(menu_long,round(8*4*60/112*RATE),menu_frames)
    gain=min(.23/np.max(np.abs(menu)),.028/np.sqrt(np.mean(menu**2)))
    menu*=gain;sf.write(MASTER/'menu_theme.wav',menu,RATE,subtype='PCM_24')
    sf.write(EXPORT/'menu_theme.wav',menu,RATE,subtype='PCM_16')
    band.chamber.write_wav(EVIDENCE/'menu-theme.wav',menu)
    native,rate=sf.read(EXPORT/'menu_theme.wav',always_2d=True);item=band.chamber.metrics(native)
    assert item['seam_delta']<.001
    item.update(file='menu_theme.wav',role='complete_menu_mix',loop=True,sha256=digest(EXPORT/'menu_theme.wav'),master_sha256=digest(MASTER/'menu_theme.wav'),bytes=(EXPORT/'menu_theme.wav').stat().st_size)
    outputs.append(item)
    # Original resolving motif, recorded guitar/strings, using the new written notes.
    saved_motif=old.MOTIF;old.MOTIF=composer.MOTIF
    for name,pb,breath in [('finish',False,False),('personal_best',True,False),('breath',False,True)]:
        event=old.event(pb,breath);event*=min(1,.20/np.max(np.abs(event)))
        target=EXPORT/(name+'.wav');sf.write(target,event,RATE,subtype='PCM_16')
        outputs.append({'file':target.name,'role':'musical_event','loop':False,'sha256':digest(target),'bytes':target.stat().st_size,'duration_seconds':len(event)/RATE})
    old.MOTIF=saved_motif
    prior=json.loads((ROOT/'game/assets/audio/locked_in_v1/manifest.json').read_text())
    for name in ['ui_select.wav','ui_confirm.wav','ui_back.wav']:
        target=EXPORT/name;shutil.copyfile(ROOT/'game/assets/audio/locked_in_v1'/name,target)
        outputs.append({'file':name,'role':'interface','loop':False,'sha256':digest(target),'bytes':target.stat().st_size})
    manifest={'schema_version':1,'asset_id':'bmt-performed-flow-2026-10-08','created_on':'2026-10-08','status':'owner_audition','menu_bpm':112,'motif_midi':composer.MOTIF,
        'generator':source_manifest,'score_source_sha256':digest(Path(__file__)),'input_sources':prior['input_sources'],'supporting_sources':prior['supporting_sources'],
        'performance_source':{'path':str(path.relative_to(ROOT)),'sha256':digest(path),'raw_near_full_scale_samples':source_manifest['metrics']['near_full_scale_samples'],
            'used_region_near_full_scale_samples':0,'detected_native_bpm':float(native_bpm),'pitch_preserving_tempo_ratio':float(ratio),'used_retimed_seconds':[12,60],
            'midi_clock_adherence':'source pulse drifted despite conditioning; measured pulse retimed to160, note adherence not claimed'},
        'component_type':'complementary spectral/rhythmic derivatives of one generated performance; not isolated instrument stems',
        'decomposition_reconstruction_error':error,'menu_delivery':'16-bit native PCM full-frame loop, no lossy decoder',
        'packages':packages,'outputs':outputs,'approval':{'user_approved':False,'scope':[]},'licensing':prior['licensing']}
    for folder in [MASTER,EXPORT]:(folder/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copyfile(Path(__file__),MASTER/'renderer.py')
    shutil.copyfile(ROOT/'game/assets/audio/locked_in_v1/CC0-LICENSE.txt',EXPORT/'CC0-LICENSE.txt')
    (EXPORT/'NOTICE.txt').write_text('Beat My Track - original performed flow score,2026-10-08.\nOriginal written MIDI theme/harmony/pulse, local Magenta RT2 performance; no reference-game audio or conditioning.\nGoogle Magenta RT2: code Apache2.0; weights CC BY4.0; Google claims no output rights. Model is not shipped. https://github.com/magenta/magenta-realtime/blob/main/MODEL.md\nSix runtime components derive from one performance and are not instrument stems. Native PCM menu, common performance theme.\nResult/interface recorded sources retain prior Karoryfer/VSCO CE CC0 licences/credits; quiet Nox CC0 gravel and project wind provenance retained in manifest.\nOwner artistic and phone listening acceptance pending.\n')
    print('PERFORMED_FLOW_EXPORT',len(outputs),sum(x['bytes'] for x in outputs),'audio bytes',flush=True)


if __name__=='__main__':main()
