"""Loop the owner-selected rally-car rail scrape without revoicing its timbre."""


def render(read, filter_audio, transpose, write, rate):
    name = "rail_scrape_pol_cc0.wav"
    source = read(name)
    # Keep the continuous middle, excluding initial contact and final settling.
    # The shared writer supplies the cyclic power crossfade and headroom;
    # no pitch change, struck-metal grains or added layers are introduced here.
    excerpt = source[round(.35*rate):round(3.65*rate)].copy()
    write("scrape",excerpt,[name],rms=.18,preserve_spectrum=True)
