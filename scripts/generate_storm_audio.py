"""Original storm ambience. NumPy is a build-only cyclic mastering tool."""
from pathlib import Path
import math
import random
import struct
import wave
import argparse
import numpy as np
from audio_loop_mastering import crossfade

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "game/assets/audio"
OUT.mkdir(parents=True, exist_ok=True)


def write(name, duration, thunder):
    rng = random.Random(19092026 if thunder else 317)
    slow = mid = 0.0
    data = bytearray()
    peak = 0.0
    count = int(RATE * duration)
    for i in range(count):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        slow += (noise - slow) * 0.018
        mid += (noise - mid) * 0.12
        if thunder:
            envelope = min(1, t / 0.12) * math.exp(-t * 0.8)
            envelope *= min(1, (duration - t) / 0.6)
            value = (slow * 3.4 + mid * 0.35 + math.sin(t * math.tau * 47) * 0.09) * envelope
        else:
            value = mid * 0.8 + noise * 0.18
        value = math.tanh(value) * 0.7
        peak = max(peak, abs(value))
        data.extend(struct.pack('<h', round(value * 32767)))
    if not thunder:
        values = crossfade(np.frombuffer(data,dtype='<i2').astype(float)/32768,RATE)
        data = np.rint(values*32767).astype('<i2').tobytes()
    with wave.open(str(OUT / name), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    print(name, 'seconds=', len(data)/(RATE*2), 'peak=', round(peak, 4))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rain-only',action='store_true',help='Repair the retained rain loop without regenerating thunder')
    args = parser.parse_args()
    write('storm_rain.wav', 6.0, False)
    if not args.rain_only: write('storm_thunder.wav', 4.5, True)
