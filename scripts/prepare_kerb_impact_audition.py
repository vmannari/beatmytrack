"""Review-only kerb direction: recorded car-bump transients and clear gaps."""
import argparse
import hashlib
import json
from pathlib import Path
import wave

import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--source-page', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert 'creativecommons.org/publicdomain/zero/1.0/' in args.source_page.read_text(encoding='utf-8-sig')
    with wave.open(str(args.source)) as stream:
        assert stream.getnchannels()==1 and stream.getsampwidth()==2 and stream.getframerate()==44100
        rate = stream.getframerate()
        source = np.frombuffer(stream.readframes(stream.getnframes()), '<i2').astype(float)/32768
    hz = np.fft.rfftfreq(len(source), 1/rate)
    eq = (1-np.exp(-(hz/75)**4))*np.exp(-(hz/4800)**4)
    filtered = np.fft.irfft(np.fft.rfft(source)*eq, n=len(source))
    cuts = [(0.55,0.95),(1.09,1.40),(5.40,5.80),(6.05,6.40),(20.19,20.50),(20.74,21.10)]
    hits, extraction = [], []
    for start, end in cuts:
        lo, hi = round(start*rate), round(end*rate)
        peak = lo+int(np.argmax(abs(filtered[lo:hi])))
        lo, hi = max(lo, peak-round(.008*rate)), min(len(source), peak+round(.165*rate))
        hit = filtered[lo:hi].copy()
        hit -= hit.mean()
        hit *= .80/max(float(max(abs(hit))), 1e-9)
        attack, release = round(.0015*rate), round(.075*rate)
        hit[:attack] *= np.linspace(0,1,attack)
        hit[-release:] *= np.linspace(1,0,release)**1.7
        hits.append(hit)
        extraction.append({'source_cut_s':[lo/rate, hi/rate], 'peak_s':peak/rate})
    # Three separate front/rear pairs, followed by a short uneven contact run.
    # The latter is illustrative timing, not an imported rumble-strip recording.
    events = [(0.55,0,.85),(0.85,1,.72),(2.0,2,.95),(2.18,3,.80),
              (3.50,4,1.0),(3.61,5,.85),
              (5.05,0,.72),(5.20,3,.58),(5.38,2,.82),(5.53,5,.64),
              (5.75,4,.78),(5.89,1,.60),(6.08,2,.72),(6.24,3,.55)]
    output = np.zeros(round(7.0*rate))
    for seconds, variation, gain in events:
        offset = round(seconds*rate)
        hit = hits[variation]*gain
        output[offset:offset+len(hit)] += hit
    output *= min(1.0, .82/max(float(max(abs(output))), 1e-9))
    assert np.isfinite(output).all() and max(abs(output)) < .83
    assert not np.any(output[round(1.15*rate):round(1.90*rate)])
    assert not np.any(output[round(3.95*rate):round(4.90*rate)])
    args.output.mkdir(parents=True, exist_ok=True)
    target = args.output/'kerb-impacts.wav'
    with wave.open(str(target),'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes(np.rint(output*32767).astype('<i2').tobytes())
    manifest = {'source':'https://freesound.org/people/acarney2019/sounds/489431/',
                'author':'acarney2019', 'title':'Driving.wav', 'licence':'CC0-1.0',
                'description':'Recorded car driving and hitting a bump; not a circuit-kerb field recording',
                'source_sha256':hashlib.sha256(args.source.read_bytes()).hexdigest(),
                'page_sha256':hashlib.sha256(args.source_page.read_bytes()).hexdigest(),
                'cuts':extraction, 'events':events, 'seconds':7.0,
                'peak':float(max(abs(output))), 'runtime_changed':False,
                'preview_sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    (args.output/'source.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print('KERB_IMPACT_AUDITION: 7 seconds, 14 recorded impacts; exact quiet gaps; no game changes')


if __name__=='__main__':
    main()
