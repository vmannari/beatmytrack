"""Verify Winter gale masters and actual native continuity, variation and silence."""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "game/assets/audio/ambience"
OUT = ROOT / "docs/evidence/winter-owner-wind-2026-10-11"


def read(path):
    with wave.open(str(path), "rb") as wav:
        assert wav.getsampwidth() == 2
        rate, channels = wav.getframerate(), wav.getnchannels()
        pcm = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").reshape(-1, channels)
    return pcm.astype(np.float64) / 32768, rate


def stats(values, rate):
    rms = float(np.sqrt(np.mean(values ** 2)))
    return dict(seconds=len(values) / rate, peak=float(np.max(np.abs(values))), rms=rms,
                rms_dbfs=float(20 * np.log10(rms)) if rms > 0 else None,
                clipped=int(np.count_nonzero(np.abs(values) >= 0.999)))


def main():
    manifest = json.loads((BANK / "winter_wind_manifest.json").read_text())
    report = dict(masters=[], native={}, silence={})
    source_dir = ROOT / "build/winter_owner_wind/sources"
    assert hashlib.sha256((source_dir / "blizzard.mp3").read_bytes()).hexdigest() == manifest["owner_source"]["sha256"]
    raw = (source_dir / "blizzard.f32").read_bytes()
    assert hashlib.sha256(raw).hexdigest() == manifest["owner_source"]["decoded_sha256"]
    source = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    for clip in manifest["clips"]:
        path = BANK / clip["filename"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == clip["sha256"]
        values, rate = read(path)
        assert rate == 44100 and values.shape[1] == 1 and len(values) == clip["seconds"] * rate
        assert values[0, 0] == values[-1, 0]
        item = stats(values, rate)
        assert item["clipped"] == 0 and item["rms"] > 0.06
        n = round(rate * 0.05)
        ratio = float(np.sqrt(np.mean(np.r_[values[-n // 2:], values[:n // 2]] ** 2)) /
                      np.sqrt(np.mean(np.r_[values[-2 * n:-n], values[n:2 * n]] ** 2)))
        assert 0.65 < ratio < 1.5
        hz = np.fft.rfftfreq(len(values), 1 / rate)
        power = np.abs(np.fft.rfft(values[:, 0])) ** 2
        centroid = float(np.sum(hz * power) / np.sum(power))
        # The owner reference replaces the rejected synthetic-brightness target.
        # Verify the recorded waveform through its documented loudness envelope.
        profile_data = (ROOT / "build/winter_owner_wind/levels" / (clip["filename"] + ".gain.f32")).read_bytes()
        assert hashlib.sha256(profile_data).hexdigest() == clip["levelling"]["gain_profile_sha256"]
        profile = np.frombuffer(profile_data, dtype="<f4").astype(np.float64)
        start = round(clip["source_start_seconds"] * rate)
        duration = round(clip["source_duration_seconds"] * rate)
        overlap = round(clip["overlap_seconds"] * rate)
        interior = source[start + overlap:start + duration - overlap]
        expected = (interior * profile[:len(interior)] - clip["dc_removed"]) * clip["applied_gain"]
        restored = np.roll(values[:, 0], clip["rotation_frames"])[:len(expected)]
        assert np.max(np.abs(restored - expected)) < 0.00004
        correlation = float(np.corrcoef(restored, expected)[0, 1])
        assert correlation > 0.99999
        item.update(filename=path.name, seam_energy_ratio=ratio, spectral_centroid_hz=centroid,
                    source_shape_correlation_after_level_gain=correlation)
        report["masters"].append(item)
    for mode in ["gale_a", "gale_b", "race0", "race1", "driving"]:
        values, rate = read(OUT / f"{mode}.wav")
        item = stats(values, rate)
        assert item["peak"] > 0.01 and item["clipped"] == 0
        n = round(rate * 0.5)
        settled = values[round(rate * 2):]
        windows = [float(np.sqrt(np.mean(settled[start:start + n] ** 2))) for start in range(0, len(settled) - n, n)]
        assert min(windows) > 0.015
        item["minimum_500ms_rms"] = min(windows)
        report["native"][mode] = item
    for mode in ["paused", "muted", "finished"]:
        values, rate = read(OUT / f"{mode}.wav")
        item = stats(values, rate)
        assert item["peak"] == 0
        report["silence"][mode] = item
    first = json.loads((OUT / "race0.json").read_text())
    second = json.loads((OUT / "race1.json").read_text())
    assert first["variant"] != second["variant"] and first["gusts"] != second["gusts"] and first["offset"] != second["offset"]
    report["variation"] = [first, second]
    (OUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__": main()
