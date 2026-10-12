"""Offline barrier screech and crash design from the bank's cleared recordings."""
import numpy as np


def render(read, steady, filter_audio, transpose, write, rate):
    def unit(values):
        return values / max(float(np.sqrt(np.mean(values**2))), 1e-8)

    collision = "collision_cc0.wav"
    body_name = "Vehicle_Truck_Body_Movement_Interior_Mono_01.wav"
    tire_name = "tires_squal_loop.wav"
    metal_name = "stone_metal_cc0.wav"
    gravel_name = "gravel_drive_cc0.wav"
    # Rubber squeal supplies the sustained strained voice; dense short grains
    # from recorded stone/metal contacts add rough barrier chatter. This is
    # authored friction foley, not a claimed recording of a particular fence.
    count = rate * 6
    squeal = np.resize(unit(filter_audio(steady(read(tire_name), 6), low=650, high=6500)), count)
    gravel = np.resize(unit(filter_audio(steady(read(gravel_name), 6), low=900, high=5500)), count)
    metal = filter_audio(read(metal_name), low=1200, high=7800)
    peak = int(np.argmax(np.abs(metal)))
    grain = metal[max(0, peak-round(.002*rate)):peak+round(.045*rate)].copy()
    grain *= np.hanning(len(grain))
    grain = unit(grain)
    chatter = np.zeros(count)
    rng = np.random.default_rng(10102026)
    cursor = 0
    while cursor < count:
        piece = transpose(grain, rng.uniform(.62, 1.36))
        size = min(len(piece), count-cursor)
        chatter[cursor:cursor+size] += piece[:size]*rng.uniform(.4, 1.0)
        cursor += int(rng.uniform(.004, .011)*rate)
    write("scrape", filter_audio(squeal*.62+unit(chatter)*.28+gravel*.10, low=350, high=7200),
          [tire_name, metal_name, gravel_name], rms=.18)

    crash = read(collision)
    body = read(body_name)
    for index, (pitch, seconds, high) in enumerate([(1.12, .22, 2800), (.94, .58, 7200), (.74, .95, 8200)]):
        source = filter_audio(transpose(crash, pitch), low=45, high=high, warmth=.3 if index else 0)
        peak = int(np.argmax(np.abs(source)))
        start = max(0, peak-round(.004*rate))
        hit = source[start:start+round(seconds*rate)].copy()
        hit *= np.exp(-np.arange(len(hit))/(rate*seconds*(.30 if index else .26)))
        hit = unit(hit)
        if index:
            # A lower body knock and irregular recorded crunch settle behind
            # the immediate attack. Heavy hits retain a fuller, longer tail.
            body_source = filter_audio(transpose(body, .90 if index==1 else .72), low=65, high=3600, warmth=.5)
            body_peak = int(np.argmax(np.abs(body_source)))
            body_cut = unit(body_source[body_peak:body_peak+round(.4*rate)])
            delay = round(.022*rate)
            size = min(len(body_cut),len(hit)-delay)
            hit[delay:delay+size] += body_cut[:size]*np.exp(-np.arange(size)/(rate*.19))*(.20 if index==1 else .38)
        write("impact_"+str(index), hit, [collision]+([body_name] if index else []), looping=False, rms=.25 if index else .23)
