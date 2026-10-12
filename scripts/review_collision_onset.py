"""Inspect sustained collision onset, rather than treating one peak as an attack."""
from pathlib import Path
import hashlib,json,wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/collision-onset-audit-2026-10-09'
OUT.mkdir(parents=True,exist_ok=True)
rows=[]
for index in range(3):
    source=ROOT/'game/assets/audio/vehicles'/f'impact_{index}.wav'
    with wave.open(str(source)) as f:
        rate=f.getframerate()
        assert f.getnchannels()==1 and f.getsampwidth()==2
        pcm=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2')
    x=pcm.astype(np.float64)/32768
    window=round(rate*.01)
    power=x*x
    rms=np.sqrt(np.convolve(power,np.ones(window)/window,mode='valid'))
    energy=np.cumsum(power)/np.sum(power)
    intervals=[]
    for start,end in [(0,1),(0,2),(0,5),(0,10),(10,20),(20,50),(50,100),(100,150)]:
        segment=x[round(start*rate/1000):round(end*rate/1000)]
        intervals.append(dict(start_ms=start,end_ms=end,rms=float(np.sqrt(np.mean(segment**2))),peak=float(np.max(np.abs(segment)))))
    rows.append(dict(file=source.name,sha256=hashlib.sha256(source.read_bytes()).hexdigest(),rate=rate,frames=len(x),duration_ms=len(x)/rate*1000,
                     first_pcm=int(pcm[0]),peak_frame=int(np.argmax(np.abs(x))),
                     leading_silence_frames=int(np.flatnonzero(np.abs(pcm)>32)[0]),
                     first_10ms_rms=float(rms[0]),loudest_10ms_rms=float(np.max(rms)),
                     loudest_10ms_start_ms=int(np.argmax(rms))/rate*1000,
                     first_10ms_relative_db=float(20*np.log10(rms[0]/np.max(rms))),
                     first_sustained_half_power_ms=int(np.flatnonzero(rms>=np.max(rms)*.7071)[0])/rate*1000,
                     energy_10pct_ms=int(np.searchsorted(energy,.1))/rate*1000,
                     energy_50pct_ms=int(np.searchsorted(energy,.5))/rate*1000,intervals=intervals))
report=dict(rows=rows,limits='Digital source waveform and sustained envelope, not an acoustic listening or speaker-latency measurement.')
for row in rows:
    assert row['leading_silence_frames']==0,row['file']
    assert row['first_10ms_relative_db']>=-.05,row['file']
    assert row['intervals'][0]['rms']>=.2,row['file']
report.update(checks=9,failures=0)
(OUT/'source-onsets.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
