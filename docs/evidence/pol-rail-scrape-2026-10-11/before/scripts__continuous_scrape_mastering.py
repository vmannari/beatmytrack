"""Sustained friction from recorded metal rubbing, with no struck-metal grains."""
import numpy as np


def render(read, filter_audio, transpose, write, rate):
    name = "continuous_metal_scrape_cc0.wav"
    source = filter_audio(transpose(read(name),.65),low=85,high=1300)
    hop = round(.025*rate)
    energy = np.array([np.sqrt(np.mean(source[i:i+hop]**2)) for i in range(0,len(source)-hop,hop)])
    reference = float(np.median(energy[energy>np.quantile(energy,.3)]))
    # Exclude contact starts, knocks and gaps; retain only real rubbing tails.
    stable = (energy>reference*.55)&(energy<reference*1.8)
    edges = np.diff(np.r_[False,stable,False].astype(np.int32))
    parts = []
    for start,end in zip(np.flatnonzero(edges==1),np.flatnonzero(edges==-1)):
        if (end-start)*hop<rate*.35: continue
        part = source[start*hop+round(.025*rate):end*hop-round(.025*rate)].copy()
        part /= max(float(np.sqrt(np.mean(part**2))),1e-9)
        parts.append(part)
    if len(parts)<3: raise ValueError("Not enough sustained friction in the cleared recording")
    rng = np.random.default_rng(11102026)
    target = rate*12
    result = np.zeros(0)
    previous = -1
    while len(result)<target:
        candidates = [index for index in range(len(parts)) if index!=previous]
        index = int(rng.choice(candidates))
        part = parts[index]
        previous = index
        if not len(result):
            result = part.copy()
            continue
        overlap = min(round(.18*rate),len(part)//2,len(result)//2)
        a,b = result[-overlap:],part[:overlap]
        correlation = float(np.clip(np.dot(a,b)/max(np.linalg.norm(a)*np.linalg.norm(b),1e-9),-.85,.99))
        ramp = .5-.5*np.cos(np.linspace(0,np.pi,overlap))
        normalization = np.sqrt((1-ramp)**2+ramp**2+2*correlation*ramp*(1-ramp))
        joined = (a*(1-ramp)+b*ramp)/normalization
        result = np.r_[result[:-overlap],joined,part[overlap:]]
    result = result[:target]
    # Gently steady continuous friction, preserving small natural fluctuations.
    window = round(.15*rate)
    padded = np.r_[result[-window//2:],result,result[:window-window//2]]
    cumulative = np.r_[0,np.cumsum(padded**2)]
    envelope = np.sqrt(np.maximum((cumulative[window:]-cumulative[:-window])[:target]/window,1e-12))
    result *= np.clip(float(np.median(envelope))/envelope,.80,1.25)
    knots = [0.0]
    while knots[-1]<12: knots.append(knots[-1]+rng.uniform(.8,1.8))
    result *= np.interp(np.arange(target)/rate,knots,rng.uniform(.90,1.10,len(knots)))
    knee = float(np.sqrt(np.mean(result**2)))*2.8
    excess = np.maximum(abs(result)-knee,0)
    result = np.sign(result)*(np.minimum(abs(result),knee)+knee*.35*np.tanh(excess/(knee*.35)))
    write("scrape",filter_audio(result,low=85,high=1300),[name],rms=.18)
