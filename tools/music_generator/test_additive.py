"""Verify actual PCM exports, not just generator metadata."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np
from additive_bank import ROOT, FRAMES, RATE, validate_score

validate_score()
manifest_path = sorted((ROOT/'build/music/additive').glob('shared-road-r3-*/manifest.json'))[-1]
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
audio = []
for job in manifest['jobs']:
    path = manifest_path.parent/job['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == job['sha256']
    with wave.open(str(path)) as f:
        assert (f.getnframes(),f.getframerate(),f.getnchannels(),f.getsampwidth()) == (FRAMES,RATE,2,2)
        a = np.frombuffer(f.readframes(FRAMES),dtype='<i2').astype(np.float32).reshape(-1,2)/32768
    assert np.isfinite(a).all() and np.sqrt(np.mean(a*a)) > .0001
    assert np.max(np.abs(a[0]-a[-1])) < .002, 'loop boundary discontinuity'
    audio.append(a)
assert len(audio) == 18
assert len({j['sha256'] for j in manifest['jobs']}) == 18
groups = [np.stack(audio[i:i+3]) for i in range(0,18,3)]
upper = sum(np.maximum(0,g.max(axis=0)) for g in groups)
lower = sum(np.minimum(0,g.min(axis=0)) for g in groups)
bound = float(max(upper.max(),-lower.min()))
assert bound < .681
result = {'result':'PASS','bank':manifest_path.parent.name,
          'checks':['all score alternatives follow exact harmonic grid',
                    'low foundation and organ answer are separated by at least an octave',
                    '18 distinct nonzero finite stereo PCM exports',
                    'all stems exactly 768000 frames / 16 seconds / 48000 Hz',
                    'each loop boundary delta below .002',
                    'sample interval bound covers all 729 combinations and arbitrary muted subsets'],
          'actual_all_subsets_sample_peak_bound':bound,
          'limitations':'Sample peaks, not oversampled true peaks. Score checks do not replace subjective listening.'}
(ROOT/'docs/evidence/music-r3/audio-results.json').write_text(json.dumps(result,indent=2))
print('PASS: R3 score/export verification (6 checks)')
