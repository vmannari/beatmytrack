"""Offline cyclic mastering for steady engines and continuous surface textures."""
import math
import numpy as np


def dominant_order(values, rate):
    frequencies = np.fft.rfftfreq(len(values), 1 / rate)
    spectrum = abs(np.fft.rfft(values * np.hanning(len(values))))
    indexes = np.flatnonzero((frequencies > 24) & (frequencies < 1600))
    index = indexes[np.argmax(spectrum[indexes])]
    correction = .5 * (spectrum[index-1] - spectrum[index+1]) / (spectrum[index-1] - 2*spectrum[index] + spectrum[index+1])
    return float((index + correction) * rate / len(values))


def recorded_cycle(values, rate, order):
    frequencies = np.fft.fftfreq(len(values), 1 / rate)
    band = (frequencies > order * .85) & (frequencies < order * 1.15)
    analytic = np.fft.ifft(np.where(band, np.fft.fft(values)*2, 0))
    phase = np.unwrap(np.angle(analytic)) / (2*np.pi)
    grid = np.arange(1024) / 1024
    # Old engine masters contain acceleration/stop transients. Collect only
    # complete forward-moving cycles with plausible duration and audible energy.
    boundaries = np.r_[0, np.flatnonzero(np.diff(phase)<=0)+1, len(phase)]
    cycles = []
    floor = np.sqrt(np.mean(values**2)) * .25
    for start, end in zip(boundaries[:-1], boundaries[1:]):
        if end-start < rate/order: continue
        region = phase[start:end]
        for number in np.arange(np.ceil(region[0]), np.floor(region[-1])):
            begin = int(np.searchsorted(region, number))
            finish = int(np.searchsorted(region, number+1))
            duration = (finish-begin) / rate
            if not .75/order < duration < 1.3/order: continue
            waveform = np.interp(number+grid, region, values[start:end])
            if np.sqrt(np.mean(waveform**2)) < floor: continue
            cycles.append(waveform)
    if len(cycles)<30:
        raise ValueError(f"Only {len(cycles)} usable recorded engine cycles")
    return np.mean(cycles, axis=0), len(cycles)


def engine_sustain(values, rate, target, seconds=8):
    source_order = dominant_order(values, rate)
    cycle, count = recorded_cycle(values, rate, source_order)
    frames = round(seconds*rate)
    if abs(target*seconds-round(target*seconds))>1e-8:
        raise ValueError("Engine sustain must contain whole firing cycles")
    grid = np.arange(len(cycle))/len(cycle)
    tonal = np.interp(np.arange(frames,dtype=float)*target/rate%1, np.r_[grid,1], np.r_[cycle,cycle[0]])
    # Preserve broad mechanical/air colour without replaying narrow wandering
    # tones or isolated source attacks. Original deterministic offline noise.
    hz = np.fft.rfftfreq(len(values),1/rate)
    power = abs(np.fft.rfft(values))**2
    edges = np.arange(0,rate/2+100,100)
    density = np.array([np.mean(power[(hz>=low)&(hz<high)]) for low,high in zip(edges[:-1],edges[1:])])
    output_hz = np.fft.rfftfreq(frames,1/rate)
    shape = np.sqrt(np.interp(output_hz,(edges[:-1]+edges[1:])/2,density))
    shape *= 1-np.exp(-(output_hz/max(400,target*2))**4)
    # Keep the fundamental band purely recorded-cycle tone. Noise in this
    # band can reintroduce low-rate phase modulation at a strong engine order.
    shape[(output_hz>target*.85)&(output_hz<target*1.15)] = 0
    rng = np.random.default_rng(11102026+round(target*1000))
    noise = np.fft.irfft(np.fft.rfft(rng.normal(0,1,frames))*shape,n=frames)
    noise *= .16*np.sqrt(np.mean(tonal**2))/max(np.sqrt(np.mean(noise**2)),1e-12)
    return tonal+noise, {"source_order_hz":source_order,"target_order_hz":target,"averaged_cycles":count}


def crossfade(values, rate, seconds=.5):
    overlap = min(round(seconds*rate),len(values)//6)
    head, tail = values[:overlap],values[-overlap:]
    correlation = float(np.clip(np.dot(head,tail)/max(np.linalg.norm(head)*np.linalg.norm(tail),1e-12),-.85,.99))
    ramp = .5-.5*np.cos(np.linspace(0,np.pi,overlap))
    normalizer = np.sqrt((1-ramp)**2+ramp**2+2*correlation*ramp*(1-ramp))
    joined = (tail*(1-ramp)+head*ramp)/normalizer
    return np.r_[values[overlap:-overlap],joined]


def level_texture(values, rate):
    # Circular 100-ms energy shaping removes repeated coarse clumps, while
    # retaining short waveform detail. Runtime movement still sets intensity.
    window = round(.1*rate)
    half = window//2
    padded = np.r_[values[-half:],values,values[:window-half]]
    cumulative = np.r_[0,np.cumsum(padded**2)]
    rms = np.sqrt(np.maximum((cumulative[window:]-cumulative[:-window])[:len(values)]/window,1e-12))
    target = float(np.median(rms))
    gain = np.clip(target/np.maximum(rms,target*.2),.3,3.0)
    return values*gain


def coherent_orders(mid_values, rate, anchors):
    # Quantize one common order/RPM ratio so all three eight-second banks have
    # whole cycles and agree during a live neighboring-layer crossfade.
    divisor = math.gcd(*anchors)
    quantum = round(dominant_order(mid_values,rate)/anchors[1]*divisor*8)
    return [anchor*quantum/(divisor*8) for anchor in anchors]
