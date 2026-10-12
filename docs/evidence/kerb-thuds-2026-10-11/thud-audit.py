from pathlib import Path
import json
import wave
import numpy as np

root = Path(__file__).resolve().parents[1]
out = root / 'docs/evidence/kerb-thuds-2026-10-11'
report = []
for label,path in [('before',out / 'before/game/assets/audio/vehicles/kerb_roll.wav'),
                   ('after',root / 'game/assets/audio/vehicles/kerb_roll.wav')]:
    with wave.open(str(path)) as handle:
        rate = handle.getframerate()
        values = np.frombuffer(handle.readframes(handle.getnframes()),dtype='<i2').astype(float)/32768
    width,hop = round(.01*rate),round(.005*rate)
    energy = np.r_[0,np.cumsum(values**2)]
    starts = np.arange(0,len(values)-width,hop)
    envelope = np.sqrt((energy[starts+width]-energy[starts])/width)
    spectrum = abs(np.fft.rfft((envelope-envelope.mean())*np.hanning(len(envelope))))**2
    hz = np.fft.rfftfreq(len(envelope),hop/rate)
    band = np.flatnonzero((hz>4)&(hz<35))
    peak = float(hz[band[np.argmax(spectrum[band])]])
    report.append(dict(case=label,envelope_peak_hz=peak,
        attack_tail_ratio=float(np.quantile(envelope,.95)/np.quantile(envelope,.05))))
assert 5.5<report[1]['envelope_peak_hz']<6.5,report
assert report[1]['attack_tail_ratio']>4, 'Thuds must have distinct attacks and tails'
(out / 'thud-review.json').write_text(json.dumps(report,indent=2)+'\n')
print('KERB_THUD_REVIEW:',report)
