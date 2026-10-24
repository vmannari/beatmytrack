"""Master CC0 recorded snow as one cyclic plough texture and one entry crunch."""
import hashlib
import json
import argparse
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/vehicle_audio_sources/snow"
OUT = ROOT / "game/assets/audio/vehicles"
RATE = 44100
IMPACT_VARIANTS = ("packed", "powder", "bank")


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


def write(name, values, looping, sources, destination=OUT):
    pcm = np.round(np.clip(values, -.999, .999) * 32767).astype("<i2")
    path = destination / (name + ".wav")
    with wave.open(str(path), "wb") as stream:
        stream.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
        stream.writeframes(pcm.tobytes())
    return {"file": path.name, "sources": sources, "loop": looping,
            "seconds": len(pcm) / RATE, "rms_dbfs": float(20 * np.log10(np.sqrt(np.mean(values ** 2)))),
            "peak_dbfs": float(20 * np.log10(max(abs(values)))),
            "seam_step": float(abs(values[0] - values[-1])) if looping else None,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def impact_fragment(recording, speed, seconds, low, high):
    """Align each independently shaped recorded compression at its real peak."""
    values = np.interp(np.arange(round(len(recording) / speed)) * speed,
                       np.arange(len(recording)), recording)
    hz = np.fft.rfftfreq(len(values), 1 / RATE)
    shape = (1 - np.exp(-(hz / low) ** 4)) * np.exp(-(hz / high) ** 4)
    values = np.fft.irfft(np.fft.rfft(values) * shape, n=len(values))
    peak = int(np.argmax(abs(values)))
    polarity = 1 if values[peak] >= 0 else -1
    begin = max(0, peak - round(RATE * .0009))
    count = round(RATE * seconds)
    fragment = np.zeros(count)
    excerpt = values[begin:begin + count] * polarity
    fragment[:len(excerpt)] = excerpt
    # Layer levels follow the first compression, rather than its quiet tail.
    fragment /= max(1e-8, np.sqrt(np.mean(fragment[:round(RATE * .10)] ** 2)))
    return fragment


def make_impact(clips, variant):
    """Original layered snow recordings; no third-party reference audio."""
    seconds = {"packed": .34, "powder": .38, "bank": .42}[variant]
    speed = {"packed": .76, "powder": .88, "bank": .62}[variant]
    compression = impact_fragment(clips[3], speed, seconds, 65, 2400 if variant == "packed" else 2900)
    body = impact_fragment(clips[3], .48 if variant != "bank" else .42, seconds, 50, 580)
    crumble = impact_fragment(clips[2], .88, seconds, 220, 3600)
    powder = impact_fragment(clips[0], .85, seconds, 180, 2400)
    if variant == "packed": values = compression*.64 + body*.44 + crumble*.16
    elif variant == "powder": values = compression*.55 + body*.30 + powder*.55
    else: values = compression*.65 + body*.65 + crumble*.18
    time = np.arange(len(values)) / RATE
    values *= np.exp(-time / (.20 if variant == "bank" else .16))
    attack = round(RATE * (.0012 if variant == "packed" else .0005))
    release = round(RATE * .045)
    values[:attack] *= np.linspace(0, 1, attack)
    values[-release:] *= np.linspace(1, 0, release)
    target = {"packed": .17, "powder": .15, "bank": .18}[variant]
    values *= target / max(1e-8, np.sqrt(np.mean(values ** 2)))
    # A rounded, bounded compression adds density without clipping the master.
    values = .86 * np.tanh(values / .86)
    if variant == "packed": values *= 10 ** (-1.5 / 20)
    values[0] = values[-1] = 0
    strong = np.flatnonzero(abs(values) >= max(abs(values)) * .5)[0] / RATE
    if strong > .005: raise ValueError("Original snow compression must begin within 5 ms")
    return values, strong


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--impact-variant", choices=IMPACT_VARIANTS, default="packed")
    parser.add_argument("--audition-dir", type=Path, default=ROOT / "build/original-snow-impact-2026-10-23/variants")
    args = parser.parse_args()
    destination = args.audition_dir.resolve()
    if not destination.is_relative_to(ROOT): raise ValueError("Audition output must stay in this workspace")
    destination.mkdir(parents=True, exist_ok=True)
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
    variants = {}
    for variant in IMPACT_VARIANTS:
        values, strong = make_impact(clips, variant)
        variants[variant] = write(variant, values, False, [records[index]["filename"] for index in ([3, 0] if variant=="powder" else [3, 2])], destination)
        variants[variant]["strong_onset_ms"] = strong * 1000
    (destination / "variants.json").write_text(json.dumps(variants, indent=2) + "\n", encoding="utf-8")
    hit, strong = make_impact(clips, args.impact_variant)
    outputs = [write("snow", bed, True, [item["filename"] for item in records[:2]]),
               write("snow_hit", hit, False, variants[args.impact_variant]["sources"])]
    manifest = {"schema": "vehicle-snow-audio-v1", "revision": 4, "rate": RATE, "channels": 1, "bits": 16,
                "design": "Unchanged dense recorded soft-snow loop. Original layered entry retains its slow 50-580 Hz recorded body. Packed snow softens compression to 2400 Hz, reduces crumble from .30 to .16, rounds the attack to 1.2 ms and eases final level by 1.5 dB. Other variants remain exact. No synthetic noise or tones; no Soundsnap samples used.",
                "impact_variant": args.impact_variant, "reference_audio_used": False,
                "entry_strong_onset_ms": float(strong * 1000),
                "license_verified_on": "2026-10-22", "sources": records, "outputs": outputs}
    (OUT / "snow_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(outputs, indent=2))


if __name__ == "__main__": main()
