"""Soft rubber/body thuds, synthesized offline without a field recording."""
import numpy as np


def render(read, steady, filter_audio, write, rate):
    count = 8*rate
    rng = np.random.default_rng(2026101153)
    # A quiet low bed joins the tails without masking the separate thuds.
    bed = filter_audio(rng.normal(size=count),low=90,high=520)
    bed /= max(float(np.sqrt(np.mean(bed**2))),1e-9)
    rolling = bed*.035
    time = np.arange(round(.13*rate),dtype=np.float64)/rate
    for index in range(48): # Six rounded thuds/s at native pitch.
        # Quickly falling rubber/body resonance, with soft attack and a short
        # damped tail. The noise transient is low-passed, never a bright click.
        pitch = rng.uniform(.96,1.04)
        phase = 2*np.pi*pitch*(105*time+45*.015*(1-np.exp(-time/.015)))
        body = np.sin(phase)+.20*np.sin(1.85*phase+.35)
        contact = filter_audio(rng.normal(size=len(time)),low=130,high=850)
        contact /= max(float(np.sqrt(np.mean(contact**2))),1e-9)
        attack = 1-np.exp(-time/.0025)
        thud = attack*(body*np.exp(-time/.027)+.16*contact*np.exp(-time/.012))
        thud[-round(.01*rate):] *= np.linspace(1,0,round(.01*rate))
        offset = round(index*rate/6)
        positions = (offset+np.arange(len(thud)))%count
        rolling[positions] += thud*rng.uniform(.93,1.0)
    # Preserve the thud envelope: shared mastering must not level individual
    # attacks into the rejected continuous flutter/noise texture.
    write("kerb_roll",filter_audio(rolling,low=65,high=1100),[],rms=.15)
