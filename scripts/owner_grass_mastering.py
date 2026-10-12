"""Continuous grass rolling made solely from the owner's two recorded rustles."""
import numpy as np


def render(read, filter_audio, write, rate):
    names = ['owner_grass_511299.wav','owner_grass_511301.wav']
    bounds = [( .32,.85),(.33,1.32)]
    recordings = []
    for name,(start,end) in zip(names,bounds):
        values = filter_audio(read(name),low=140,high=4200)
        values = values[round(start*rate):round(end*rate)]
        values /= max(float(np.sqrt(np.mean(values**2))),1e-9)
        recordings.append(values)
    count = 12*rate
    cloud = np.zeros(count)
    rng = np.random.default_rng(2026101157)
    cursor,index = 0,0
    while cursor<count:
        source = recordings[index%2]
        # Alternate both recordings. Variable excerpts and overlapping soft
        # joins remove the original isolated-swish gaps without new noise/tones.
        length = min(len(source),round(rng.uniform(.45,.72)*rate))
        offset = int(rng.integers(0,len(source)-length+1))
        grain = source[offset:offset+length].copy()
        fade = min(round(.12*rate),length//3)
        ramp = .5-.5*np.cos(np.linspace(0,np.pi,fade))
        grain[:fade] *= ramp
        grain[-fade:] *= ramp[::-1]
        positions = (cursor+np.arange(length))%count
        cloud[positions] += grain*rng.uniform(.85,1.05)
        cursor += round(rng.uniform(.20,.30)*rate)
        index += 1
    # Slow circular energy control keeps it continuous while preserving the
    # fine texture. This is a half-second window, not flattened100ms noise.
    width = round(.5*rate)
    padded = np.r_[cloud[-width//2:],cloud,cloud[:width-width//2]]
    energy = np.r_[0,np.cumsum(padded**2)]
    envelope = np.sqrt(np.maximum((energy[width:]-energy[:-width])[:count]/width,1e-12))
    target = float(np.median(envelope))
    cloud *= np.clip(target/np.maximum(envelope,target*.35),.65,1.5)
    write('grass',filter_audio(cloud,low=140,high=4200),names,rms=.115)
