"""Audit the scoped kerb replacement and native auditions, preserving other audio."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

root = Path(__file__).resolve().parents[1]
out = root / 'docs/evidence/kerb-refinement-2026-10-11'
bank = root / 'game/assets/audio/vehicles'
before = json.loads((out / 'before-hashes.json').read_text(encoding='utf-8-sig'))
changed = [item['file'] for item in before if hashlib.sha256((bank / item['file']).read_bytes()).hexdigest()!=item['sha256']]
assert changed==['kerb_roll.wav'], changed
manifest = json.loads((bank / 'manifest.json').read_text())
clip = next(item for item in manifest['outputs'] if item['file']=='kerb_roll.wav')
assert clip['sources']==['kerb_rumble_cc0.wav']
source = next(item for item in manifest['sources'] if item['filename']==clip['sources'][0])
assert source['license']=='CC0-1.0'

def read(path):
    with wave.open(str(path)) as handle:
        assert handle.getsampwidth()==2
        rate, channels = handle.getframerate(), handle.getnchannels()
        values = np.frombuffer(handle.readframes(handle.getnframes()),dtype='<i2').astype(float)/32768
    return values.reshape(-1,channels), rate

values, rate = read(bank / 'kerb_roll.wav')
hz = np.fft.rfftfreq(len(values),1/rate)
power = abs(np.fft.rfft(values[:,0]))**2
report = dict(changed_wavs=changed, unchanged_wavs=len(before)-1,
    loop_seconds=len(values)/rate, loop_bytes=(bank / 'kerb_roll.wav').stat().st_size,
    low_mid_energy_fraction=float(power[(hz>=80)&(hz<1750)].sum()/power.sum()), captures=[])
assert report['low_mid_energy_fraction']>.90, 'Kerb must remain a tyre/body rumble'
for case in ['grass-entry','kerb-cross','kerb-ride','kerb-speeds']:
    for suffix in ['', '-grass', '-kerb']:
        path = out / (case+suffix+'.wav')
        values, rate = read(path)
        peak = float(abs(values).max())
        tail = float(abs(values[-round(.15*rate):]).max())
        assert peak<.95 and tail==0, (path.name,peak,tail)
        if suffix=='-kerb' and case!='grass-entry': assert peak>.04, 'Kerb is inaudible'
        if suffix=='-kerb' and case=='grass-entry': assert peak==0, 'False kerb on grass'
        report['captures'].append(dict(file=path.name,peak=peak,pause_tail_peak=tail))
(out / 'audio-review.json').write_text(json.dumps(report,indent=2)+'\n')
print('KERB_REFINEMENT_REVIEW:',len(report['captures']),'native captures;',report['unchanged_wavs'],'other WAVs exact')
