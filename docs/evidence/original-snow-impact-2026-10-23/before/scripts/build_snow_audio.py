"""Master CC0 recorded snow as one cyclic plough texture and one entry crunch."""
import hashlib
import json
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/vehicle_audio_sources/snow"
OUT = ROOT / "game/assets/audio/vehicles"
RATE = 44100


def read(record):
    path = SOURCE / record["filename"]
    if hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
        raise ValueError("Source changed: " + path.name)
    with wave.open(str(path), "rb") as stream:
        frames, width, channels, rate = stream.getnframes(), stream.getsampwidth(), stream.getnchannels(), stream.getframerate()
        raw = stream.readframes(frames)
    if width == 3:
        data = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int32)
        data = (data[:, 0] | data[:, 1] << 8 | data[:, 2] << 16)
        values = ((data ^ 0x800000) - 0x800000) / 8388608.0
    elif width == 2:
        values = np.frombuffer(raw, "<i2").astype(float) / 32768
    else:
        raise ValueError("Expected recorded 16/24-bit PCM")
    values = values.reshape(-1, channels).mean(axis=1)
    values = np.interp(np.arange(round(len(values) * RATE / rate)) * rate / RATE, np.arange(len(values)), values)
    active = np.flatnonzero(np.abs(values) > max(abs(values)) * .015)
    return values[max(0, active[0] - 220):min(len(values), active[-1] + 440)]


def finish(values, rms, high=3000):
    hz = np.fft.rfftfreq(len(values), 1 / RATE)
    shape = (1 - np.exp(-(hz / 85) ** 4)) * np.exp(-(hz / high) ** 4)
    values = np.fft.irfft(np.fft.rfft(values) * shape, n=len(values))
    values *= min(rms / np.sqrt(np.mean(values ** 2)), .82 / max(abs(values)))
    return values


def write(name, values, looping, sources):
    pcm = np.round(np.clip(values, -.999, .999) * 32767).astype("<i2")
    path = OUT / (name + ".wav")
    with wave.open(str(path), "wb") as stream:
        stream.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
        stream.writeframes(pcm.tobytes())
    return {"file": path.name, "sources": sources, "loop": looping,
            "seconds": len(pcm) / RATE, "rms_dbfs": float(20 * np.log10(np.sqrt(np.mean(values ** 2)))),
            "peak_dbfs": float(20 * np.log10(max(abs(values)))),
            "seam_step": float(abs(values[0] - values[-1])) if looping else None,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    records = json.loads((SOURCE / "manifest.json").read_text(encoding="utf-8"))
    clips = [read(record) for record in records]
    rng = np.random.default_rng(22102026)
    frames = RATE * 6
    bed = np.zeros(frames)
    # Short, densely overlapped soft-snow grains remove individual footfalls
    # and the former flutter/crackling. All material is from the recordings.
    cursor = 0
    for number in range(600):
        source = clips[number % 2]
        count = min(len(source), int(RATE * rng.uniform(.035, .070)))
        start = int(rng.integers(0, len(source) - count + 1))
        grain = source[start:start + count].copy()
        grain *= min(6.0, .07 / max(np.sqrt(np.mean(grain ** 2)), 1e-8))
        grain *= np.sin(np.linspace(0, np.pi, count)) ** 1.5
        grain *= rng.uniform(.8, 1.05)
        np.add.at(bed, (np.arange(count) + cursor) % frames, grain)
        cursor += int(RATE * rng.uniform(.008, .014))
    # Cyclic 150 ms energy control restrains obvious isolated step accents.
    window = np.zeros(frames)
    width = int(RATE * .15)
    window[:width] = 1 / width
    energy = np.sqrt(np.maximum(1e-10, np.fft.irfft(np.fft.rfft(bed ** 2) * np.fft.rfft(window), n=frames)))
    bed *= np.clip(np.median(energy) / energy, .5, 2.0)
    bed = finish(bed, .16)
    # Keep the sample step across the cyclic boundary below one PCM quantum.
    # A tiny local endpoint correction avoids changing the recorded spectrum.
    correction = bed[-1] - bed[0]
    count = 256
    bed[-count:] -= correction * np.linspace(0, 1, count)
    # A short, weighty compression with its actual attack at contact. The old
    # landing retained a 90 ms approach before its main crunch. Slow the source
    # for body weight, then trim to 1 ms before the strongest compression.
    compression = np.interp(np.arange(round(len(clips[3]) / .72)) * .72, np.arange(len(clips[3])), clips[3])
    compression = finish(compression, .23, high=2600)
    begin = max(0, int(np.argmax(abs(compression))) - round(RATE * .001))
    hit = compression[begin:begin + round(RATE * .28)].copy()
    hit[:round(RATE * .0007)] *= np.linspace(0, 1, round(RATE * .0007))
    hit[-round(RATE * .025):] *= np.linspace(1, 0, round(RATE * .025))
    strong = np.flatnonzero(abs(hit) > max(abs(hit)) * .5)[0] / RATE
    if strong > .005: raise ValueError("Snow compression must have an audible attack within 5 ms")
    outputs = [write("snow", bed, True, [item["filename"] for item in records[:2]]),
               write("snow_hit", hit, False, [records[3]["filename"]])]
    manifest = {"schema": "vehicle-snow-audio-v1", "revision": 2, "rate": RATE, "channels": 1, "bits": 16,
                "design": "Dense 35-70 ms soft-snow overlap with 150 ms cyclic energy control, 85-3000 Hz shaping and cyclic join. Entry is a slower recorded compression trimmed to its attack, with 85-2600 Hz shaping. No synthetic noise or tones.",
                "entry_strong_onset_ms": float(strong * 1000),
                "license_verified_on": "2026-10-22", "sources": records, "outputs": outputs}
    (OUT / "snow_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(outputs, indent=2))


if __name__ == "__main__": main()
