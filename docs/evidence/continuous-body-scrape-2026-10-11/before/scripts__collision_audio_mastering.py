"""Offline barrier screech and crash design from the bank's cleared recordings."""
import numpy as np


def render(read, steady, filter_audio, transpose, write, rate):
    def unit(values):
        return values / max(float(np.sqrt(np.mean(values**2))), 1e-8)

    collision = "owner_crash_394903.wav"
    body_name = "Vehicle_Truck_Body_Movement_Interior_Mono_01.wav"
    tire_name = "tires_squal_loop.wav"
    metal_name = "stone_metal_cc0.wav"
    # Slow, uneven mechanical rubbing replaces the rejected dense radio-like
    # chatter. Low pitched recorded tails breathe in irregular longer strokes.
    count = rate * 12
    squeal = np.resize(unit(filter_audio(transpose(steady(read(tire_name), 6),.70), low=180, high=2000)), count)
    panel = np.resize(unit(filter_audio(steady(transpose(read(body_name),.72),12), low=90, high=1400)), count)
    metal = filter_audio(read(metal_name), low=200, high=6000)
    block = round(.02*rate)
    energy = [(float(np.mean(metal[start:start+block]**2)),start)
              for start in range(0,len(metal)-round(.24*rate),block)]
    selected = []
    for _,start in sorted(energy,reverse=True):
        if all(abs(start-old)>round(.4*rate) for old in selected): selected.append(start)
        if len(selected)==4: break
    grains = []
    for start in selected:
        segment = metal[max(0,start-round(.02*rate)):start+round(.24*rate)]
        peak = int(np.argmax(np.abs(segment)))
        grain = segment[max(0,peak-round(.002*rate)):peak+round(.22*rate)].copy()
        attack = min(round(.035*rate),len(grain))
        grain[:attack] *= np.linspace(0,1,attack)
        grain *= np.exp(-np.arange(len(grain))/(rate*.14))
        release = min(round(.055*rate),len(grain)//3)
        grain[-release:] *= np.linspace(1,0,release)
        grains.append(unit(grain))
    chatter = np.zeros(count)
    rng = np.random.default_rng(10102026)
    cursor = 0
    while cursor < count:
        piece = transpose(grains[int(rng.integers(len(grains)))], rng.uniform(.46, .68))
        size = min(len(piece), count-cursor)
        chatter[cursor:cursor+size] += piece[:size]*rng.uniform(.40, 1.0)
        cursor += int(rng.uniform(.09, .31)*rate)
    # Uneven pressure changes are authored offline and survive final mastering;
    # never impose a fixed pulsing rate or flatten these strokes into static.
    knots = [0.0]
    while knots[-1]<12.0: knots.append(knots[-1]+rng.uniform(.22,.75))
    pressure = np.interp(np.arange(count)/rate,knots,rng.uniform(.42,1.0,len(knots)))
    texture = filter_audio((unit(chatter)*.60+panel*.35+squeal*.05)*pressure, low=85, high=2400)
    # Bend rare sharp grain peaks smoothly so the common bank ceiling does
    # not lower the sustained grind's loudness compared with the old scrape.
    knee = float(np.sqrt(np.mean(texture**2)))*2.8
    magnitude = abs(texture)
    excess = np.maximum(magnitude-knee,0)
    texture = np.sign(texture)*(np.minimum(magnitude,knee)+knee*.35*np.tanh(excess/(knee*.35)))
    write("scrape", texture,
          [metal_name, body_name, tire_name], rms=.18)

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
