"""Offline recorded friction and owner-selected crash mastering."""
import numpy as np


def render(read, steady, filter_audio, transpose, write, rate):
    collision = "owner_crash_394903.wav"
    from continuous_scrape_mastering import render as render_scrape
    render_scrape(read,filter_audio,transpose,write,rate)

    crash = read(collision)
    # Keep the owner's heavy crash at its original pitch and retain its tail.
    # Softer contacts use shorter/filtered cuts of that same recording.
    for index, (pitch, seconds, high) in enumerate([(1.05, .26, 3300), (1.0, .68, 6500), (1.0, 2.0, 10000)]):
        source = filter_audio(transpose(crash, pitch) if pitch!=1.0 else crash, low=30, high=high)
        peak = int(np.argmax(np.abs(source)))
        hit = source[peak:peak+round(seconds*rate)].copy()
        if index<2:
            hit *= np.exp(-np.arange(len(hit))/(rate*(.14 if index==0 else .40)))
        write("impact_"+str(index), hit, [collision], looping=False, rms=.25 if index else .23)
