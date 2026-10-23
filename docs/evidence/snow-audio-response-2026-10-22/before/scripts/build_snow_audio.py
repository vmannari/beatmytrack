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


def finish(values, rms):
    hz = np.fft.rfftfreq(len(values), 1 / RATE)
    shape = (1 - np.exp(-(hz / 115) ** 4)) * np.exp(-(hz / 5100) ** 4)
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
    # Dense, irregular overlapping *recorded* grains remove the human walking
    # cadence. All deposits wrap cyclically; no generated noise or tones.
    cursor = 0
    for number in range(110):
        source = clips[number % 3]
        count = min(len(source), int(RATE * rng.uniform(.14, .28)))
        start = int(rng.integers(0, len(source) - count + 1))
        grain = source[start:start + count].copy()
        grain *= .11 / max(np.sqrt(np.mean(grain ** 2)), 1e-8)
        grain *= np.sin(np.linspace(0, np.pi, count)) ** .65
        grain *= rng.uniform(.75, 1.12)
        np.add.at(bed, (np.arange(count) + cursor) % frames, grain)
        cursor += int(RATE * rng.uniform(.045, .08))
    bed = finish(bed, .18)
    # Keep the sample step across the cyclic boundary below one PCM quantum.
    # A tiny local endpoint correction avoids changing the recorded spectrum.
    correction = bed[-1] - bed[0]
    count = 256
    bed[-count:] -= correction * np.linspace(0, 1, count)
    hit = finish(clips[3], .23)
    fade = min(440, len(hit) // 8)
    hit[:fade] *= np.linspace(0, 1, fade)
    hit[-fade:] *= np.linspace(1, 0, fade)
    outputs = [write("snow", bed, True, [item["filename"] for item in records[:3]]),
               write("snow_hit", hit, False, [records[3]["filename"]])]
    manifest = {"schema": "vehicle-snow-audio-v1", "revision": 1, "rate": RATE, "channels": 1, "bits": 16,
                "design": "Recorded snow granular overlap, 115-5100 Hz EQ, cyclic join and level/headroom mastering; entry from recorded snow compression. No synthetic noise or tones.",
                "license_verified_on": "2026-10-22", "sources": records, "outputs": outputs}
    (OUT / "snow_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(outputs, indent=2))


if __name__ == "__main__": main()
