"""Low continuous curb rolling from existing cleared driving/body recordings."""
import numpy as np


def render(read, steady, filter_audio, write, rate):
    def unit(values):
        return values/max(float(np.sqrt(np.mean(values**2))),1e-9)
    gravel = "gravel_drive_cc0.wav"
    body = "Vehicle_Truck_Body_Movement_Interior_Mono_01.wav"
    rolling = unit(filter_audio(steady(read(gravel),6.0),low=70,high=1300))
    tap = filter_audio(read(body),low=85,high=1200)
    peak = int(np.argmax(abs(tap)))
    tap = tap[peak:peak+round(.075*rate)].copy()
    tap *= np.exp(-np.arange(len(tap))/(rate*.015))
    tap *= np.hanning(len(tap))
    tap = unit(tap)
    count = len(rolling)
    vibration = np.zeros(count)
    rng = np.random.default_rng(11102027)
    cursor = 0
    while cursor<count:
        size = min(len(tap),count-cursor)
        vibration[cursor:cursor+size] += tap[:size]*rng.uniform(.75,1.0)
        cursor += round(rng.uniform(.020,.030)*rate)
    write("kerb_roll",filter_audio(rolling*.78+unit(vibration)*.22,low=70,high=1600),[gravel,body],rms=.17)
