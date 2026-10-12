"""Granular rolling/spray and body-impact design from pinned CC0 recordings."""
import numpy as np


def render(read, steady, filter_audio, transpose, write, rate):
    def unit(x):
        return x / max(float(np.max(np.abs(x))), 1e-8)

    def cut(x, seconds):
        peak = int(np.argmax(np.abs(x)))
        start = max(0, peak - round(.004 * rate))
        result = x[start:start + round(seconds * rate)].copy()
        result *= np.exp(-np.arange(len(result)) / (rate * seconds * .26))
        return result

    metal = "stone_metal_cc0.wav"
    gravel = "gravel_drive_cc0.wav"
    collision = "collision_cc0.wav"
    dirty = "Vehicle_Truck_Drive_Dirty_Ground_Exterior_Loop_Stereo.wav"
    grass = "Vehicle_Truck_Drive_Grass_Exterior_Loop_Stereo.wav"
    # Match the granular tire noise and chassis rumble independently. Remove
    # engine harmonics from the dirty-ground master, retain gravel transients.
    rolling = unit(filter_audio(steady(read(gravel), 5.8), low=85, high=1400))
    write("sand_roll", rolling, [gravel], rms=.13)
    spray = unit(filter_audio(steady(read(gravel), 5.8), low=1050, high=8800))
    dirt = unit(filter_audio(steady(read(dirty), 5.8), low=1900, high=8500))
    # Avoid a bright constant hiss; blend granular recorded driving with the
    # sand swish, no footfall pulse and no synthesized oscillator.
    size = min(len(spray), len(dirt))
    write("sand", spray[:size] * .82 + dirt[:size] * .18, [gravel, dirty], rms=.14)
    write("loose", filter_audio(steady(read(gravel), 5.8), low=180, high=6800), [gravel], rms=.14)
    write("grass", filter_audio(steady(read(grass), 5.8), low=180, high=5800), [grass], rms=.14)
    # Individual stone contacts: separate attacks from a real stone-on-surface
    # recording. High-pass plus short damped tails evokes underside metal taps.
    taps = filter_audio(read(metal), low=1050, high=8800)
    window = round(.016 * rate)
    energy = np.array([np.mean(taps[i:i+window] ** 2) for i in range(0, len(taps)-window, window)])
    selected = []
    for block in np.argsort(energy)[::-1]:
        offset = int(block * window)
        if all(abs(offset - old) > rate * .55 for old in selected):
            selected.append(offset)
        if len(selected) == 6:
            break
    for index in range(3):
        start = max(0, selected[index] - round(.03 * rate))
        tap = cut(taps[start:start + round(.25 * rate)], .115 + index * .018)
        write("grit_" + str(index), tap, [metal], looping=False, rms=.19)
    # Desert ejects a continuous fine stream. Render hundreds of irregular,
    # overlapping short stone grains offline; never schedule sparse impacts
    # or hundreds of AudioStreamPlayers in the game.
    rng = np.random.default_rng(8102026)
    count = rate * 10
    cloud = np.zeros(count, dtype=np.float64)
    grains = []
    for offset in selected:
        start = max(0, offset - round(.03 * rate))
        grain = cut(taps[start:start+round(.15*rate)], .035)
        grains.append(grain / max(np.sqrt(np.mean(grain**2)),1e-8))
    cursor = 0.0
    while cursor < count/rate:
        cursor += rng.exponential(1.0/320.0)
        offset = round(cursor*rate)
        if offset >= count:
            break
        grain = transpose(grains[int(rng.integers(len(grains)))],rng.uniform(.85,1.65))
        grain = grain[:round(rng.uniform(.012,.026)*rate)].copy()
        grain *= np.exp(-np.arange(len(grain))/(rate*.006))
        grain[:min(20,len(grain))] *= np.linspace(0,1,min(20,len(grain)))
        length = min(len(grain),count-offset)
        cloud[offset:offset+length] += grain[:length]*rng.uniform(.45,.85)
    # Keep detail in the waveform while removing large-scale clumps that read
    # as isolated hits. This is offline envelope shaping, not a periodic gate.
    hop = round(.02*rate)
    envelope = np.array([np.sqrt(np.mean(cloud[i:i+hop]**2)) for i in range(0,count,hop)])
    target = float(np.median(envelope))
    gain = np.clip(target/np.maximum(envelope,target*.35),.45,2.0)
    cloud *= np.interp(np.arange(count),np.arange(len(gain))*hop+hop*.5,gain)
    granular = filter_audio(steady(read(gravel),10.0),low=1300,high=8200)
    granular = granular[:count]
    cloud /= max(np.sqrt(np.mean(cloud**2)),1e-8)
    granular /= max(np.sqrt(np.mean(granular**2)),1e-8)
    write("sand_debris", filter_audio(cloud*.72+granular*.28,low=1150,high=7800), [metal,gravel], rms=.14)
    # Severity banks: a compact damped bump, an unmistakable crumple and a
    # heavier body hit with debris/settling. Clips are chosen by impulse, rather
    # than rotating identical door slams regardless of contact force.
    crash = read(collision)
    body_name = "Vehicle_Truck_Body_Movement_Interior_Mono_01.wav"
    body = unit(filter_audio(steady(read(body_name), .6), low=120, high=3800))
    # Kerbs, landings and shifts need an immediate transient. The former
    # steady-energy segment reached its strongest body knock 104ms late.
    write("chassis", cut(filter_audio(read(body_name), low=80, high=7000), .26), [body_name], looping=False, rms=.16)
    for index, (pitch, seconds, high) in enumerate([(1.12, .22, 2600), (1.0, .48, 6800), (.86, .72, 7800)]):
        hit = unit(cut(filter_audio(transpose(crash, pitch), low=55, high=high), seconds))
        if index > 0:
            tail = np.zeros(len(hit))
            delay = round(.035 * rate)
            count = min(len(body), len(hit) - delay)
            tail[delay:delay+count] = body[:count] * np.exp(-np.arange(count)/(rate*.16))
            hit += tail * (.14 if index == 1 else .22)
        write("impact_" + str(index), hit, [collision] + ([body_name] if index else []), looping=False, rms=.23)
