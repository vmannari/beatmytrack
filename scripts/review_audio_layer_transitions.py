"""Check gain bumps during native runtime transitions, with identical sound files."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/evidence/audio-layer-transitions-2026-10-10"


def read(path):
    with wave.open(str(path)) as handle:
        rate,channels=handle.getframerate(),handle.getnchannels()
        x=np.frombuffer(handle.readframes(handle.getnframes()),"<i2").astype(float)/32768
    return x.reshape(-1,channels),rate


def main():
    baseline=json.loads((OUT/"before-audio-hashes.json").read_text())
    changes=[p for p,digest in baseline.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=digest]
    # A separate live workspace edit changed the unused thunder one-shot.
    # Preserve it and report it explicitly; it never enters this Engine-bus
    # fixture, whose events are required to remain zero. Every input bank stays pinned.
    assert not any(p.startswith("game/assets/audio/vehicles/") for p in changes),"Keep every captured source file unchanged"
    assert set(changes)<= {"game/assets/audio/storm_thunder.wav"},"Unexpected concurrent audio changes"
    capture=json.loads((OUT/"native-capture.json").read_text())
    assert capture["failures"]==0 and len(capture["reports"])==8
    rows=[]
    for item in capture["reports"]:
        p=OUT/f'{item["variant"]}-{item["fixture"]}.wav'
        x,rate=read(p)
        assert len(x)/rate>14.5 and .02<np.max(abs(x))<.9
        assert np.max(abs(x[-rate//2:]))==0
        windows=[]
        for start in np.arange(.5,13.4,.1):
            block=x[round(start*rate):round((start+.1)*rate)]
            windows.append((float(start),float(np.sqrt(np.mean(block**2)))))
        times=np.array([t for t,rms in windows]);levels=np.array([rms for t,rms in windows])
        low=float(np.median(levels[(times>.7)&(times<1.7)]))
        high=float(np.median(levels[(times>6.5)&(times<7.5)]))
        sweep=(times>2.2)&(times<5.8)|(times>8.2)&(times<11.8)
        peak=float(np.max(levels[sweep]))
        bump=float(20*np.log10(peak/max(low,high)))
        dip=float(20*np.log10(float(np.min(levels[sweep]))/min(low,high)))
        assert np.min(levels)>np.median(levels)*.1,p.name+": dropout"
        rows.append({"variant":item["variant"],"fixture":item["fixture"],"low_endpoint_rms":low,"high_endpoint_rms":high,
                     "overlap_peak_rms":peak,"overlap_bump_db":bump,"overlap_dip_db":dip,"peak":float(np.max(abs(x))),"paused_tail_peak":0,
                     "shifts":item["shifts"],"events":item["events"],"stream_count":item["streams"]})
    for fixture in ("low_mid","mid_high","full_range","load_coast"):
        before=next(r for r in rows if r["fixture"]==fixture and r["variant"]=="before")
        after=next(r for r in rows if r["fixture"]==fixture and r["variant"]=="after")
        assert after["overlap_bump_db"]<.75,(fixture,"transition gain bump remains")
        # Distinct recorded pulse shapes allow a modest sub-dB RMS dip; a
        # larger hole reveals destructive interference on layer reentry.
        assert after["overlap_dip_db"]>-1.0,(fixture,"transition phase cancellation remains")
        if fixture=="load_coast":
            assert before["overlap_bump_db"]>1.0 and before["overlap_bump_db"]-after["overlap_bump_db"]>1.0
        elif fixture in ("low_mid","full_range"):
            assert before["overlap_dip_db"]<-1.5 and after["overlap_dip_db"]-before["overlap_dip_db"]>1.0
    report={"audio_files_unchanged":len(baseline)-len(changes),"vehicle_input_files_unchanged":47,"concurrent_audio_changes":changes,"native_transitions":rows,
            "limitation":"Confirmed gain bumps corrected; owner's exact remaining artefact and triggering situation still require listening."}
    (OUT/"review.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    cards=[]
    for fixture,label in [("low_mid","Low/mid RPM layers"),("mid_high","Mid/high RPM layers"),("full_range","Low to high RPM and return"),("load_coast","Throttle/coast layers")]:
        cards.append(f'<article><h2>{label}</h2><p>Before</p><audio controls preload="metadata" src="before-{fixture}.wav"></audio><p>After</p><audio controls preload="metadata" src="after-{fixture}.wav"></audio></article>')
    page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Engine layer transitions</title><style>body{background:#101b27;color:#eee5d6;font:17px/1.5 system-ui;margin:0}main{max-width:780px;margin:40px auto;padding:24px}article{padding:20px;border:1px solid #405466;border-radius:12px;margin:20px 0}h2{color:#ffd667}audio{width:100%}small{color:#b4bfcc}</style><main><h1>Engine layer transitions</h1><p>Matched native runtime captures, identical sound files and a fixed presentation envelope. Each holds an endpoint, moves across the blend, holds the other endpoint, returns, then pauses.</p><p>These isolate already-playing engine layers; no shifts, body cues, tyres or weather are present. Final engine recordings retain Nox Sound Design CC0 provenance and original offline texture design.</p>'''+"".join(cards)+'''<small>RMS analysis confirms the overlap gain correction. Exact owner artefact and device listening remain unconfirmed. Natural tone changes between layers remain.</small></main><script>document.querySelectorAll('audio').forEach(p=>p.addEventListener('play',()=>document.querySelectorAll('audio').forEach(q=>{if(p!==q)q.pause()})))</script></html>'''
    (OUT/"audition.html").write_text(page,encoding="utf-8")
    print(json.dumps(report,indent=2))


if __name__=="__main__":main()
