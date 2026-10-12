"""Recorded tyre rumble, using a cleared car-on-rumble-strips pass."""


def render(read, steady, filter_audio, write, rate):
    source = "kerb_rumble_cc0.wav"
    # Keep the close tyre pass, excluding its quiet approach/departure. The
    # normal circular envelope mastering removes the pass-by volume swell;
    # the real irregular tyre vibration stays inside the loop. No repeated
    # body hits, gravel swish, synthesized pulses or fixed knocking rhythm.
    rolling = steady(read(source),2.8,start=6.6)
    write("kerb_roll",filter_audio(rolling,low=80,high=1750,warmth=.35),[source],rms=.15)
