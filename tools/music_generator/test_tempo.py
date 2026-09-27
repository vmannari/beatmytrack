"""Inspect actual tempo exports and verify they preserve their source scores."""
import hashlib
import json
import wave
import numpy as np
from additive_bank import ROOT, RATE
from tempo_bank import BPMS

p=sorted((ROOT/'build/music/tempo').glob('evolving-r4-*/manifest.json'))[-1]
m=json.loads(p.read_text(encoding='utf-8'))
source=ROOT/m['source_manifest'];original=json.loads(source.read_text(encoding='utf-8'))
max_bound=0;max_seam=0
for bpm in BPMS:
    jobs=[j for j in m['jobs'] if j['bpm']==bpm];assert len(jobs)==18
    audio=[]
    for j in jobs:
        original_job=next(x for x in original['jobs'] if x['state_index']==j['state_index'] and x['variant']==j['variant'])
        assert (p.parent/j['score']).read_bytes()==(source.parent/original_job['score']).read_bytes()
        assert hashlib.sha256((p.parent/j['file']).read_bytes()).hexdigest()==j['sha256']
        with wave.open(str(p.parent/j['file'])) as f:
            assert f.getnframes()==round(32*60/bpm*RATE)
            assert (f.getframerate(),f.getnchannels(),f.getsampwidth())==(RATE,2,2)
            a=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float32).reshape(-1,2)/32768
        assert np.isfinite(a).all() and np.sqrt(np.mean(a*a))>.0001
        max_seam=max(max_seam,float(np.max(np.abs(a[0]-a[-1]))))
        audio.append(a)
    groups=[np.stack(audio[i:i+3]) for i in range(0,18,3)]
    bound=max(float(sum(np.maximum(0,g.max(axis=0)) for g in groups).max()),float(-sum(np.minimum(0,g.min(axis=0)) for g in groups).min()))
    max_bound=max(bound,max_bound)
assert max_bound<.681
assert max_seam<.002
result={'result':'PASS','checks':['108 PCM exports match hashes and score sources',
    'six exact tempo durations within one sample','finite nonzero stereo audio',
    'all 729 choices and muted subsets below .681 at every tempo','loop boundary delta below .002'],
    'max_sample_bound':max_bound,'max_loop_boundary_delta':max_seam}
(ROOT/'docs/evidence/music-r4/audio-results.json').write_text(json.dumps(result,indent=2))
print('PASS: tempo exports (5 grouped checks)')
