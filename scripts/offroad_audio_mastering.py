"""Natural recorded offroad rolling with narrow motor tones and hiss restrained."""
import numpy as np


def suppress_tones(values):
    # Overlapped spectral attenuation reduces narrow motor harmonics in the
    # recordings while retaining broad tyre/foliage texture and original phase.
    size,hop = 4096,1024
    window = np.hanning(size)
    padded = np.pad(values,(size,size),mode='reflect')
    result,weight = np.zeros(len(padded)),np.zeros(len(padded))
    for start in range(0,len(padded)-size+1,hop):
        spectrum = np.fft.rfft(padded[start:start+size]*window)
        magnitude = abs(spectrum)
        neighborhoods = np.lib.stride_tricks.sliding_window_view(np.pad(magnitude,(8,8),mode='edge'),17)
        local = np.median(neighborhoods,axis=-1)
        gain = np.clip((local*2.5/np.maximum(magnitude,1e-12))**.75,.20,1.0)
        result[start:start+size] += np.fft.irfft(spectrum*gain,n=size)*window
        weight[start:start+size] += window**2
    return (result/np.maximum(weight,1e-12))[size:size+len(values)]


def render(read, steady, filter_audio, write, rate):
    from owner_grass_mastering import render as render_grass
    render_grass(read,filter_audio,write,rate)
    sources = [('loose','gravel_drive_cc0.wav',180,2600,.12)]
    for name,source,low,high,rms in sources:
        # Use real rolling/rustle, without synthesized bass notes or body bumps
        # that could sound like rough engine firing when blended into the race.
        recorded = filter_audio(read(source),low=low,high=high)
        values = suppress_tones(steady(recorded,7.5 if name=='grass' else 12.5))
        write(name,filter_audio(values,low=low,high=high),[source],rms=rms)
