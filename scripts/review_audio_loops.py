"""Complete PCM/Ogg loop inventory, waveform/phase audit and wrap listening pack."""
from pathlib import Path
import argparse
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/all-audio-loops-2026-10-10"
DECODE = ROOT / "build/audio_loop_audit"


def read(path):
    with wave.open(str(path)) as handle:
        rate, channels = handle.getframerate(), handle.getnchannels()
        assert handle.getsampwidth()==2
        x = np.frombuffer(handle.readframes(handle.getnframes()),"<i2").astype(float)/32768
    return x.reshape(-1,channels),rate


def measure(x,rate):
    width = round(.04*rate)
    levels = np.array([np.sqrt(np.mean(block**2)) for block in np.array_split(x,max(1,len(x)//width))])
    median = float(np.median(levels))
    seam = float(np.max(abs(x[0]-x[-1])))
    derivative = float(np.quantile(abs(np.diff(x,axis=0)),.9995))
    return {"seconds":len(x)/rate,"channels":x.shape[1],"peak":float(np.max(abs(x))),
            "rms":float(np.sqrt(np.mean(x**2))),"minimum_40ms_relative_db":float(20*np.log10(max(min(levels),1e-12)/max(median,1e-12))),
            "maximum_40ms_relative_db":float(20*np.log10(max(levels)/max(median,1e-12))),
            "seam_step":seam,"reference_step":derivative,"seam_ratio":seam/max(derivative,1e-12),
            "dropout_windows":int(np.sum(levels<max(.0003,median*.04)))}


def phase_span(x,rate,target):
    mono=x.mean(axis=1)
    hz=np.fft.fftfreq(len(mono),1/rate)
    band=(hz>target*.9)&(hz<target*1.1)
    z=np.fft.ifft(np.where(band,np.fft.fft(mono)*2,0))
    phase=np.unwrap(np.angle(z))
    rates=np.gradient(phase)*rate/(2*np.pi)
    window=round(.02*rate)
    cumulative=np.r_[0,np.cumsum(rates)]
    smooth=(cumulative[window:]-cumulative[:-window])/window
    low,high=np.percentile(smooth,[5,95])
    return {"median_hz":float(np.median(smooth)),"p5_hz":float(low),"p95_hz":float(high),"span_hz":float(high-low)}


def write(path,x,rate):
    pcm=np.rint(np.clip(x,-.999,.999)*32767).astype("<i2")
    with wave.open(str(path),"wb") as handle:
        handle.setnchannels(x.shape[1]);handle.setsampwidth(2);handle.setframerate(rate);handle.writeframes(pcm.tobytes())


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listening",action="store_true")
    args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    baseline=json.loads((OUT/"before-audio-hashes.json").read_text())
    bank=ROOT/"game/assets/audio/vehicles"
    manifest=json.loads((bank/"manifest.json").read_text())
    entries=[];failures=[]
    for item in manifest["outputs"]:
        if not item["loop"]:continue
        entries.append({"file":"game/assets/audio/vehicles/"+item["file"],"kind":"engine" if "engine_order_hz" in item else "texture",
                        "target_order_hz":item.get("engine_order_hz"),"enabled":item["file"]!="wet_road.wav","shipping":True})
    for filename,kind in [("ambience/night_cicadas.wav","ambience"),("ambience/storm_rain_recorded.wav","ambience"),("locked_in_v1/menu_theme.wav","music")]:
        entries.append({"file":"game/assets/audio/"+filename,"kind":kind,"shipping":True,"enabled":True})
    entries.append({"file":"game/assets/audio/storm_rain.wav","kind":"ambience","shipping":True,"enabled":False,"retained_legacy":True})
    for entry in entries:
        p=ROOT/entry["file"];x,rate=read(p);stats=measure(x,rate)
        entry.update(stats,rate=rate,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
        old=OUT/"before"/entry["file"]
        if old.exists():
            a,r=read(old);entry["before"]=measure(a,r)
        if stats["seam_step"]>stats["reference_step"]*1.5+3/32768:failures.append(entry["file"]+": discontinuous source seam")
        if entry["kind"]!="music" and stats["dropout_windows"]:failures.append(entry["file"]+": sustained-loop dropout")
        if stats["peak"]>=.9:failures.append(entry["file"]+": inadequate headroom")
        if entry["kind"]=="engine":
            entry["phase"]=phase_span(x,rate,entry["target_order_hz"])
            if entry["phase"]["span_hz"]>.3:failures.append(entry["file"]+": repeating pitch variation")
            if min(abs(entry["phase"]["median_hz"]-entry["target_order_hz"]),1)>.05:failures.append(entry["file"]+": incoherent playback order")
            if stats["minimum_40ms_relative_db"] < -1.1:failures.append(entry["file"]+": repeating engine envelope dip")
        if args.listening:
            label=p.stem
            # Tail/head and one full repeat expose source seams and recurrent events.
            context=min(round(2*rate),len(x)//2)
            excerpt=np.r_[x[-context:],x[:context],x[-context:],x[:context]]
            write(OUT/("after-"+label+"-wrap.wav"),excerpt,rate)
            if old.exists():
                a,r=read(old);context=min(round(2*r),len(a)//2)
                write(OUT/("before-"+label+"-wrap.wav"),np.r_[a[-context:],a[:context],a[-context:],a[:context]],r)
    oggs=json.loads((DECODE/"decoded.json").read_text())
    for item in oggs:
        x=np.fromfile(DECODE/item["decoded"],dtype="<f4").reshape(-1,2).astype(float)
        count=round(item["length"]*item["rate"])
        body=x[:count];stats=measure(body,item["rate"])
        actual_seam=float(np.max(abs(x[count]-x[count-1])))
        stats["native_wrap_step"]=actual_seam
        if actual_seam>stats["reference_step"]*1.5+.003:failures.append(item["file"]+": encoded native wrap discontinuity")
        if not np.all(np.isfinite(x)) or stats["peak"]>=.99:failures.append(item["file"]+": nonfinite/clipped decode")
        entry={"file":"game/"+item["file"],"kind":"music","shipping":item["shipping"],"enabled":False,"sha256":item["sha256"],"rate":item["rate"],**stats}
        entries.append(entry)
        if args.listening:
            context=round(2*item["rate"])
            # Engine decode already contains the real wrap; include its suffix.
            write(OUT/("music-"+Path(item["decoded"]).stem+"-wrap.wav"),x[count-context:count+round(.25*item["rate"])],item["rate"])
    assert len(entries)==85 and len({e["file"] for e in entries})==85
    changed=[]
    for filename,old_hash in baseline.items():
        new_hash=hashlib.sha256((ROOT/filename).read_bytes()).hexdigest()
        if new_hash!=old_hash:changed.append(filename)
    loop_paths={e["file"] for e in entries}
    assert all(p in loop_paths for p in changed),"Do not alter one-shots"
    assert not any("locked_in_v1" in p or "score_v1" in p or "night_cicadas" in p for p in changed)
    native=[]
    if (OUT/"native-mixes.json").exists():
        capture=json.loads((OUT/"native-mixes.json").read_text())
        assert capture["failures"]==0 and len(capture["reports"])==5
        for item in capture["reports"]:
            values,rate=read(OUT/(item["car"]+"-native-mix.wav"))
            assert len(values)/rate>26.5 and .02<np.max(abs(values))<.9
            assert np.max(abs(values[-rate//2:]))==0
            region=values[round(.5*rate):round(25.5*rate)]
            stats=measure(region,rate)
            assert stats["dropout_windows"]==0 and item["shifts"]==0
            assert min(item["wraps"][i] for i in [1,2,4,5])>=2
            native.append({**item,**stats,"paused_tail_peak":0})
    report={"loop_count":len(entries),"pcm_loops":44,"ogg_loops":41,"shipping_loops":sum(e["shipping"] for e in entries),
            "disabled_shipping_music":30,"retained_export_excluded_music":11,"changed_audio":changed,
            "unchanged_audio":len(baseline)-len(changed),"entries":entries,"native_mixes":native,"failures":failures}
    (OUT/"audit.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    if args.listening:
        cards=[]
        for kind in ["engine","texture","ambience","music"]:
            cards.append(f'<h2>{kind.capitalize()}</h2>')
            for e in entries:
                if e["kind"]!=kind:continue
                p=Path(e["file"]);label=p.stem
                after="after-"+label+"-wrap.wav" if p.suffix==".wav" else "music-"+p.parent.name+"_"+label+"-wrap.wav"
                old="before-"+label+"-wrap.wav"
                controls=f'<p>Before</p><audio controls preload="none" src="{old}"></audio>' if (OUT/old).exists() else ""
                cards.append(f'<article><h3>{p.parent.name}/{label}</h3>{controls}<p>Current wrap</p><audio controls preload="none" src="{after}"></audio></article>')
        native_cards=''.join(f'<article><h3>{item["car"].capitalize()} native mix</h3><audio controls preload="none" src="{item["car"]}-native-mix.wav"></audio></article>' for item in native)
        page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>All audio loop audit</title><style>body{background:#101b27;color:#eee5d6;font:16px/1.5 system-ui;margin:0}main{max-width:900px;margin:40px auto;padding:24px}article{padding:16px;border:1px solid #405466;border-radius:10px;margin:16px 0}h2,h3{color:#ffd667}audio{width:100%}small{color:#b4bfcc}</style><main><h1>Complete loop review</h1><p>85 looping assets, including retained legacy rain. PCM excerpts cross the wrap twice. Music excerpts use the pinned decoder’s actual wrap. Natural texture and subjective sound quality still require listening; music remains disabled during races.</p><p><a href="wind-level-matched/index.html">Level-matched wind comparison</a></p><h2>Native vehicle mixes</h2>'''+native_cards+"".join(cards)+'''<small>Vehicle/rolling masters: Nox Sound Design, Joseph SARDIN and DenisChardonnet (CC0); authored recorded-cycle sustains and original offline noise. Tire squeal: audible-edge/Tom Haigh, loop edit qubodup, CC BY 3.0; resampled, filtered, leveled, crossfaded. Cicadas: Clarisse, CC0. Rain: owner-supplied Dragon Studio filename attribution, original licence metadata unavailable. Music provenance and full source/derivative credits remain in each asset bank's NOTICE/manifest. No subjective listening or device acceptance is claimed.</small></main><script>document.querySelectorAll('audio').forEach(p=>p.addEventListener('play',()=>document.querySelectorAll('audio').forEach(q=>{if(p!==q)q.pause()})))</script></html>'''
        (OUT/"audition.html").write_text(page,encoding="utf-8")
    print(json.dumps({"loops":len(entries),"changed_audio":len(changed),"unchanged_audio":report["unchanged_audio"],"failures":failures},indent=2))
    return int(bool(failures))


if __name__=="__main__":raise SystemExit(main())
