"""Offline barrier screech and crash design from the bank's cleared recordings."""
import numpy as np


def render(read, steady, filter_audio, transpose, write, rate):
    def unit(values):
        return values / max(float(np.sqrt(np.mean(values**2))), 1e-8)

    collision = "collision_cc0.wav"
    body_name = "Vehicle_Truck_Body_Movement_Interior_Mono_01.wav"
    tire_name = "tires_squal_loop.wav"
    metal_name = "stone_metal_cc0.wav"
    # Long, nearly untransposed metal tails retain their ringing modes as
    # overlapping abrasive grains. Body-panel vibration supports that metal
    # grind; rubber squeal is only a restrained strain layer. This is authored
    # friction foley, not a claimed field recording of a particular fence.
    count = rate * 6
    squeal = np.resize(unit(filter_audio(steady(read(tire_name), 6), low=650, high=6500)), count)
    panel = np.resize(unit(filter_audio(steady(read(body_name), 6), low=160, high=1900)), count)
    metal = filter_audio(read(metal_name), low=420, high=8800)
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
        grain = segment[max(0,peak-round(.002*rate)):peak+round(.16*rate)].copy()
        attack = min(round(.003*rate),len(grain))
        grain[:attack] *= np.linspace(0,1,attack)
        grain *= np.exp(-np.arange(len(grain))/(rate*.065))
        grain[-round(.02*rate):] *= np.linspace(1,0,round(.02*rate))
        grains.append(unit(grain))
    chatter = np.zeros(count)
    rng = np.random.default_rng(10102026)
    cursor = 0
    while cursor < count:
        piece = transpose(grains[int(rng.integers(len(grains)))], rng.uniform(.94, 1.06))
        size = min(len(piece), count-cursor)
        chatter[cursor:cursor+size] += piece[:size]*rng.uniform(.55, 1.0)
        cursor += int(rng.uniform(.006, .016)*rate)
    # Preserve narrow recorded metallic resonances instead of blurring them
    # with broad pitch jitter. Mechanical rasp supplies body weight underneath.
    texture = filter_audio(unit(chatter)*.76+panel*.16+squeal*.08, low=180, high=8200)
    # Bend rare sharp grain peaks smoothly so the common bank ceiling does
    # not lower the sustained grind's loudness compared with the old scrape.
    knee = float(np.sqrt(np.mean(texture**2)))*2.8
    magnitude = abs(texture)
    excess = np.maximum(magnitude-knee,0)
    texture = np.sign(texture)*(np.minimum(magnitude,knee)+knee*.35*np.tanh(excess/(knee*.35)))
    write("scrape", texture,
          [metal_name, body_name, tire_name], rms=.18)

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
