"""Owner-recording wind variants and retained original wind-blown sand, mastered offline."""
from pathlib import Path
import hashlib
import json
import argparse
import subprocess
import wave

import numpy as np
from audio_loop_mastering import crossfade

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "game/assets/audio/ambience"
RATE = 44100
SEED = 20261010
SOURCE = ROOT / "build/desert_owner_wind/sources"
SOURCE_FILENAME = "tanweraman-desert-wind-1-350398.mp3"
SOURCE_HASH = "c64ada53695793738ea9ba9cc81ba593c1886445860e215359e9b980e1b469a5"
WIND_REGIONS = [("desert_wind.wav", 0.6, 14.0),
                ("desert_wind_b.wav", 7.4, 16.0),
                ("desert_wind_c.wav", 13.6, 14.0)]
LEVELS = ROOT / "build/desert_wind_presence/levels"


def circular_mean(values, frames):
    half = frames // 2
    padded = np.r_[values[-half:], values, values[:frames - half]]
    cumulative = np.r_[0.0, np.cumsum(padded, dtype=np.float64)]
    return ((cumulative[frames:] - cumulative[:-frames]) / frames)[:len(values)]


def level_wind(values):
    # Preserve recorded waveform/pitch while gently lifting its quiet passages.
    rms = np.sqrt(np.maximum(circular_mean(values ** 2, round(0.75 * RATE)), 1e-12))
    target = float(np.median(rms))
    gain = np.clip(target / np.maximum(rms, target * 0.1), 0.45, 4.0)
    gain = circular_mean(gain, round(0.5 * RATE))
    return values * gain, gain


def band_noise(rng, count, low, high):
    hz = np.fft.rfftfreq(count, 1 / RATE)
    spectrum = np.fft.rfft(rng.standard_normal(count))
    spectrum *= (1 - np.exp(-(hz / low) ** 4)) * np.exp(-(hz / high) ** 4)
    values = np.fft.irfft(spectrum, n=count)
    return values / np.sqrt(np.mean(values ** 2))


def slow_envelope(rng, seconds, count, floor):
    time = np.arange(count, dtype=np.float64) / RATE
    values = np.zeros(count)
    for harmonic in range(1, 6):
        values += np.sin(2 * np.pi * harmonic * time / seconds + rng.uniform(0, 2 * np.pi)) / harmonic
    values = (values - values.min()) / (values.max() - values.min())
    return floor + (1 - floor) * values


def sand(rng, seconds):
    count = seconds * RATE
    # Fine dry movement, with many tiny damped grains rather than pebble hits.
    hiss = band_noise(rng, count, 1100, 6200)
    grains = np.zeros(count)
    for _ in range(seconds * 65):
        start = int(rng.integers(0, count))
        length = int(rng.integers(round(0.005 * RATE), round(0.025 * RATE)))
        grain = rng.standard_normal(length) * np.sin(np.linspace(0, np.pi, length)) ** 2
        grain *= rng.uniform(0.06, 0.20)
        indexes = (start + np.arange(length)) % count
        grains[indexes] += grain
    spectrum = np.fft.rfft(grains)
    hz = np.fft.rfftfreq(count, 1 / RATE)
    spectrum *= (1 - np.exp(-(hz / 1300) ** 4)) * np.exp(-(hz / 5500) ** 4)
    grains = np.fft.irfft(spectrum, n=count)
    grains /= np.sqrt(np.mean(grains ** 2))
    return (hiss * 0.72 + grains * 0.28) * slow_envelope(rng, seconds, count, 0.65)


def write(filename, values, seconds, rms_db, peak_db=-7, recorded=False):
    dc = float(values.mean())
    values -= dc
    gain = min(10 ** (rms_db / 20) / np.sqrt(np.mean(values ** 2)),
               10 ** (peak_db / 20) / np.max(np.abs(values)))
    values *= gain
    # Original sand is periodic; recorded wind has a power-preserving join. Rotate to a
    # quiet continuous boundary; do not fade to silence at every loop join.
    delta = np.abs(np.diff(values, append=values[0]))
    candidates = np.flatnonzero(np.abs(values) < np.sqrt(np.mean(values ** 2)) * 0.05)
    seam = int(candidates[np.argmin(delta[candidates])])
    if recorded:
        # Recorded wind can swell strongly around a mathematically quiet sample.
        # Also match 50ms seam energy to neighboring regions to avoid a join bump.
        size = round(RATE * 0.05)
        quantized = np.round(values * 32767)
        matching = candidates[quantized[candidates] == quantized[(candidates + 1) % len(values)]]
        for candidate in matching[np.argsort(delta[matching])[:128]]:
            origin = int(candidate) + 1
            joined = values[(origin + np.arange(-size // 2, size // 2)) % len(values)]
            neighbors = values[(origin + np.r_[np.arange(-size * 2, -size), np.arange(size, size * 2)]) % len(values)]
            ratio = np.sqrt(np.mean(joined ** 2)) / np.sqrt(np.mean(neighbors ** 2))
            if 0.85 < ratio < 1.15:
                seam = int(candidate)
                break
        else:
            raise ValueError("No quiet, energy-consistent recorded wind seam")
    values = np.roll(values, -(seam + 1))
    pcm = np.round(values * 32767).astype("<i2")
    target = BANK / filename
    with wave.open(str(target), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    return dict(filename=filename, seconds=seconds, rate=RATE, channels=1, bytes=target.stat().st_size,
                sha256=hashlib.sha256(target.read_bytes()).hexdigest(), rms_dbfs=float(20 * np.log10(np.sqrt(np.mean(values ** 2)))),
                peak_dbfs=float(20 * np.log10(np.max(np.abs(values)))), seam_step=float(abs(int(pcm[-1]) - int(pcm[0])) / 32768),
                largest_sample_step=float(np.max(np.abs(np.diff(pcm.astype(np.int32)))) / 32768),
                rotation_frames=seam + 1, dc_removed=dc, applied_gain=gain)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--decode", action="store_true", help="Decode cached owner MP3 through scripts/dev.ps1")
    args = parser.parse_args()
    source_data = (SOURCE / "wind.mp3").read_bytes()
    if hashlib.sha256(source_data).hexdigest() != SOURCE_HASH:
        raise ValueError("Owner wind source changed; review before rebuilding")
    if args.decode:
        command = "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/decode_storm_rain_source.gd -TestArgument @('--source-path=res://../build/desert_owner_wind/sources/wind')"
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command], cwd=ROOT, check=True)
    decoded = json.loads((SOURCE / "wind.decode.json").read_text())
    raw = (SOURCE / "wind.f32").read_bytes()
    if hashlib.sha256(raw).hexdigest() != decoded["sha256"]:
        raise ValueError("Decoded owner wind checksum changed")
    source = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    if decoded["rate"] != RATE:
        positions = np.arange(round(len(source) * RATE / decoded["rate"]), dtype=np.float64) * decoded["rate"] / RATE
        source = np.interp(positions, np.arange(len(source), dtype=np.float64), source)
    BANK.mkdir(parents=True, exist_ok=True)
    entries = []
    for filename, start, duration in WIND_REGIONS:
        if start + duration > len(source) / RATE:
            raise ValueError("Wind excerpt extends past owner recording")
        region = source[round(start * RATE):round((start + duration) * RATE)].copy()
        loop = crossfade(region, RATE, seconds=2.0)
        loop, level_gain = level_wind(loop)
        LEVELS.mkdir(parents=True, exist_ok=True)
        profile = level_gain.astype("<f4").tobytes()
        (LEVELS / (filename + ".gain.f32")).write_bytes(profile)
        item = write(filename, loop, len(loop) / RATE, -23, peak_db=-5.0, recorded=True)
        item.update(source_start_seconds=start, source_duration_seconds=duration,
                    overlap_seconds=2.0, origin="Owner-supplied recording; original pitch, no EQ or added wind layers",
                    levelling=dict(rms_window_seconds=0.75, gain_smoothing_seconds=0.5, minimum_gain=0.45, maximum_gain=4.0,
                                   gain_profile_sha256=hashlib.sha256(profile).hexdigest()))
        entries.append(item)
    entries.append(write("desert_dune_sand.wav", sand(np.random.default_rng(SEED + 1), 29), 29, -26))
    manifest = dict(author="Owner wind filename attribution: TanwerAman; dune sand: Beat my track original offline sound design",
                    origin="Wind derives from explicitly supplied recording; original dune-sand asset retained",
                    owner_source=dict(filename=SOURCE_FILENAME, sha256=SOURCE_HASH, decoded_sha256=decoded["sha256"],
                                      seconds=decoded["source_seconds"], license="Original licence metadata not supplied; no CC0 licence inferred"),
                    seed=SEED, build_tool="scripts/build_desert_ambience.py; NumPy offline only",
                    design="Three overlapping recorded wind regions, original pitch/tone, mono44.1kHz16-bit PCM; 0.75s circular RMS levelling with 0.5s gain smoothing lifts lulls; DC removal/level matching/-5dBFS peak cap/2s power joins/quiet seam rotation. No EQ, synthetic wind or runtime generation. Existing 29s original dune sand unchanged.",
                    clips=entries, total_bytes=sum(item["bytes"] for item in entries))
    (BANK / "desert_ambience_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
