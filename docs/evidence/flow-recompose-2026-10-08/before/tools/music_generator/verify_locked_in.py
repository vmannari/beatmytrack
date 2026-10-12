"""Validate the shared band world and actual confidence/breath/PB mixer recordings."""
from pathlib import Path
import argparse
import hashlib
import html
import itertools
import json
import math

import numpy as np
import verify_score_v1 as audio

ROOT=Path(__file__).resolve().parents[2]
BANK=ROOT/'game/assets/audio/locked_in_v1'
EVIDENCE=ROOT/'docs/evidence/locked-in-score-2026-10-07'
audio.WORK=ROOT/'build/music/locked-in-v1/verification'


def main():
    audio.WORK.mkdir(parents=True,exist_ok=True)
    m=json.loads((BANK/'manifest.json').read_text()); decoded={}; assets=[]
    assert m['motif_midi']==[62,64,69,66] and len(m['packages'])==5
    for source in m['input_sources']['sources']:
        path=ROOT/'build/music/locked-in-v1/sources'/source['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest()==source['sha256']
    for clip in m['outputs']:
        path=BANK/clip['file'];assert hashlib.sha256(path.read_bytes()).hexdigest()==clip['sha256']
        pcm,rate=audio.read(path);result=audio.measure(pcm,rate);result['file']=path.name
        assert result['clipped_samples']==0 and result['true_peak_dbtp']<-4
        if clip['loop']:
            assert len(pcm)==clip['frames'] and rate==44100 and pcm.shape[1]==2
            result['seam_delta']=float(np.max(np.abs(pcm[0]-pcm[-1])))
            assert result['seam_delta']<0.008 and result['mono_rms_ratio']>.85
            decoded[path.name]=pcm
        assets.append(result)
    combinations=[]
    for package in m['packages']:
        assert package['frames']==2352000 and package['bpm']==144 and package['motif']==m['motif_midi']
        layers=[decoded[name] for name in package['layers']]
        for weights in itertools.product([0,1],repeat=5):
            pcm=layers[0]+sum(part*w for part,w in zip(layers[1:],weights))
            result=audio.measure(pcm,44100)
            assert result['clipped_samples']==0 and result['true_peak_dbtp']<-3
            assert result['mono_rms_ratio']>.85
            result.update(biome=package['id'],layers=[1,*weights]);combinations.append(result)
    captures=[]
    for path in sorted(EVIDENCE.glob('godot-*.wav')):
        pcm,rate=audio.read(path);result=audio.measure(pcm,rate);result['file']=path.name
        assert result['clipped_samples']==0 and result['true_peak_dbtp']<0
        if path.name!='godot-interface-music.wav':assert result['rms_dbfs']>-70
        if 'palette' in path.name:
            result['pause_tail']=float(np.max(np.abs(pcm[-round(rate*.35):])))
            assert result['pause_tail']==0
        if path.name=='godot-interface.wav':
            result['silent_hover_focus']=float(np.max(np.abs(pcm[:round(rate*.6)])))
            assert result['silent_hover_focus']==0
        captures.append(result)
    assert len(captures)==18,'Run the full actual mixer capture'
    trace=json.loads((EVIDENCE/'runtime-trace.json').read_text());assert trace['failures']==0 and 59<=trace['full_at_seconds']<63
    breath=[x for x in trace['trace'] if 0.08<x['breath']<1.0]
    assert breath and any(x['music_db']<=-79 for x in breath),'Actual two-beat drop must mute the score'
    report={'sources':len(m['input_sources']['sources']),'assets':assets,'combinations':combinations,'captures':captures,'full_at_seconds':trace['full_at_seconds'],'breath_muted_samples':breath,'listening_performed':False,'shipping_audio_bytes':sum(x['bytes'] for x in m['outputs'])}
    (EVIDENCE/'audio-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    page(trace)
    print('LOCKED_IN_VERIFY',len(assets),'assets',len(combinations),'combinations',len(captures),'actual captures; 0 clipped samples')
    print('EXCEPTIONAL_FULL',trace['full_at_seconds'],'seconds; breath and pause/hover silence verified')


def page(trace):
    m=json.loads((BANK/"manifest.json").read_text())
    is_rock=m.get("asset_id","").startswith("bmt-sports-rock")
    prefix="" if is_rock else "mix4/"
    cards=[('Menu - the four-note identity',prefix+'menu-theme.wav','Electric guitar states D-E-A-F# over bass/room pulse at 112 BPM. Exact 34.286-second loop.')]
    descriptions={'pine':'Warm guitar, finger bass and a close/room acoustic kit. Fragmented bass/pulse is filled into a band groove and recognizable hook.',
        'desert':'Dryer rhythmic colour, tremolo guitar and quiet gravel percussion, within the same theme.',
        'winter':'Sparse piano motif, thinner shimmering guitar colour and a more spacious room. Drums join through confidence.',
        'night_city':'Tight recorded-kit timing, filtered guitar and bass texture. The same motif stays underneath.',
        'storm':'Heavier kit colour, rough low guitar texture and quiet wind-derived rain rhythm. The theme is preserved.'}
    if is_rock:
        descriptions.update(pine='Muted electric-guitar riff, driven melodic responses, finger bass and a firm acoustic backbeat. Chorus guitars and quiet strings/pad support the payoff.',
            desert='Drier drum colour, beat-locked tremolo guitar and quiet gravel percussion retain the same sporty riff and motif.',
            winter='Piano and shimmering guitar colour give the rock rhythm more space; the common riff and confidence-driven kit remain.',
            night_city='Tighter kit timing and filtered driven guitar/bass create a precise version of the same rock identity.',
            storm='Heavier kit, rough driven guitar and quiet wind-derived rain rhythm develop the same motif.')
    for biome in ['pine','desert','winter','night_city','storm']:
        cards.append((biome.replace('_',' ').title()+' - clean confidence story',prefix+biome+'-clean-story.wav',descriptions[biome]+' 144 BPM, offline 90-second confidence illustration.'))
    cards.extend([
        ('Actual mixer - flow, car and breath','godot-flow-story.wav',f"Scripted clean-sector signals with the real car-audio model. Soaring layer at {trace['full_at_seconds']:.2f}s; one controlled breath requested at 70s. These are mixer fixtures, not a claimed player PB."),
        ('Actual mixer - 0.08-second PB','godot-pb-80ms.wav','Scripted 0.08-second improvement selects the resolving motif sting. Actual player records are never fabricated.'),
        ('Activation-only menu sounds','godot-interface.wav','One silent second for hover/focus; then select, confirm and back.')])
    articles=[]
    for title,file,description in cards:
        marker='<div class="markers"><button data-seek="0">Fragment</button><button data-seek="16">Groove</button><button data-seek="30">Hook</button><button data-seek="60">Soar</button></div>' if 'story' in file else ''
        articles.append(f'<article><h2>{html.escape(title)}</h2><p>{html.escape(description)}</p><audio controls preload="metadata" src="{file}"></audio>{marker}</article>')
    document='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Beat My Track - Locked In</title>
<style>*{box-sizing:border-box}body{margin:0;background:#0b141e;color:#edf0e9;font:17px/1.6 system-ui,sans-serif}main{max-width:1000px;margin:48px auto;padding:0 24px}h1{font-size:42px;line-height:1.1}h2{font-size:24px;line-height:1.3}.eyebrow{color:#ffd348;font-size:13px;letter-spacing:.1em}p{color:#afbfcc}article{padding:24px;margin:22px 0;background:#12222e;border:1px solid #344e5d;border-radius:14px}audio{width:100%}button{padding:10px 16px;border:0;border-radius:8px;background:#ffd348;color:#101b27;cursor:pointer}.markers{display:flex;flex-wrap:wrap;gap:10px;margin-top:12px}.arc{color:#ffd348;padding:16px;border:1px solid #344e5d;border-radius:10px}footer{padding:24px 0;color:#9caebc;font-size:14px}</style>
<main><div class="eyebrow">BEAT MY TRACK - SHARED BAND WORLD</div><h1>The music locks in with you.</h1><p>A four-note motif, recorded guitar/bass/acoustic drums and five related palettes. Clean sectors and controlled lines build confidence; available PB/rival ghost data adds context. No raw-speed intensity mapping. Artistic and phone listening remain pending.</p><div class="arc">Fragmented → coherent → driving → euphoric · Soaring is reserved for exceptional flow.</div>
'''+''.join(articles)+'''<footer>Original written score and sample performances; CC0 Karoryfer band recordings, VSCO 2 CE support, Nox gravel and project-authored wind processing. Source renders, licences and hashes preserved. No agent subjective listening or finished AAA quality is claimed.</footer></main>
<script>document.querySelectorAll('audio').forEach(a=>a.addEventListener('play',()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()})));document.querySelectorAll('[data-seek]').forEach(b=>b.addEventListener('click',()=>{const a=b.closest('article').querySelector('audio');a.currentTime=Number(b.dataset.seek);a.play().catch(e=>{if(e.name!=='AbortError')throw e})}));</script></html>'''
    if is_rock:
        document=document.replace('Beat My Track - Locked In','Beat My Track - Sports Rock')
        document=document.replace('BEAT MY TRACK - SHARED BAND WORLD','BEAT MY TRACK - SPORTS ROCK REVISION')
        document=document.replace('A four-note motif, recorded guitar/bass/acoustic drums and five related palettes.',
            'An original four-note motif, muted and overdriven electric guitars, chorus colour, finger bass and a stronger acoustic backbeat. Quiet strings and baked analog-style textures supply atmosphere across five related palettes.')
        document=document.replace('<div class="arc">','<p><a style="color:#ffd348" href="comparison/index.html">Compare the previous and new score at equal loudness</a></p><div class="arc">')
    (EVIDENCE/'audition.html').write_text(document,encoding='utf-8')


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--evidence-dir',type=Path);args=parser.parse_args()
    if args.evidence_dir:
        EVIDENCE=(ROOT/args.evidence_dir).resolve()
        if not EVIDENCE.is_relative_to((ROOT/'docs/evidence').resolve()):raise ValueError('Evidence must stay under docs/evidence')
        audio.WORK=ROOT/'build/music'/EVIDENCE.name/'verification'
    main()
