"""Check owner-wind masters, native variation, loop continuity and lifecycle silence."""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "game/assets/audio/ambience"
OUT = ROOT / "docs/evidence/desert-wind-presence-2026-10-11"


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
    manifest = json.loads((BANK / "desert_ambience_manifest.json").read_text())
    report = {"masters": [], "native": {}, "silence": {}}
    source_dir = ROOT / "build/desert_owner_wind/sources"
    source = np.frombuffer((source_dir / "wind.f32").read_bytes(), dtype="<f4").astype(np.float64)
    assert hashlib.sha256((source_dir / "wind.mp3").read_bytes()).hexdigest() == manifest["owner_source"]["sha256"]
    assert hashlib.sha256((source_dir / "wind.f32").read_bytes()).hexdigest() == manifest["owner_source"]["decoded_sha256"]
    for clip in manifest["clips"]:
        path = BANK / clip["filename"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == clip["sha256"]
        values, rate = read(path)
        assert rate == 44100 and values.shape[1] == 1 and len(values) == clip["seconds"] * rate
        assert abs(values[-1, 0] - values[0, 0]) == 0
        item = stats(values, rate)
        assert item["clipped"] == 0 and item["rms"] > 0.04
        # The loop join has no fade dip, relative to its surrounding sound.
        size = round(rate * 0.05)
        join = np.r_[values[-size // 2:], values[:size // 2]]
        neighbors = np.r_[values[-size * 2:-size], values[size:size * 2]]
        ratio = float(np.sqrt(np.mean(join ** 2)) / np.sqrt(np.mean(neighbors ** 2)))
        assert 0.65 < ratio < 1.5
        item.update(filename=path.name, seam_step=0.0, seam_rms_ratio=ratio)
        if clip["filename"].startswith("desert_wind"):
            overlap = round(clip["overlap_seconds"] * rate)
            start = round(clip["source_start_seconds"] * rate)
            duration = round(clip["source_duration_seconds"] * rate)
            interior = source[start + overlap:start + duration - overlap]
            restored = np.roll(values[:, 0], clip["rotation_frames"])
            profile_data = (ROOT / "build/desert_wind_presence/levels" / (clip["filename"] + ".gain.f32")).read_bytes()
            assert hashlib.sha256(profile_data).hexdigest() == clip["levelling"]["gain_profile_sha256"]
            profile = np.frombuffer(profile_data, dtype="<f4").astype(np.float64)
            expected = (interior * profile[:len(interior)] - clip["dc_removed"]) * clip["applied_gain"]
            assert np.max(np.abs(restored[:len(expected)] - expected)) < 0.00004
            correlation = float(np.corrcoef(restored[:len(expected)], expected)[0, 1])
            assert correlation > 0.99999
            item["source_shape_correlation_after_level_gain"] = correlation
        report["masters"].append(item)
    for mode in ["wind", "wind_b", "wind_c", "sand", "mixed0", "mixed1"]:
        values, rate = read(OUT / f"{mode}.wav")
        item = stats(values, rate)
        assert item["peak"] > 0.003 and item["clipped"] == 0
        if mode == "sand":
            sand_peak = report["masters"][-1]["peak"]
            assert item["peak"] <= sand_peak * 0.065625 + 0.0001
        size = round(rate * 0.05)
        settled = values[round(rate * 2.5):]
        rms_windows = [float(np.sqrt(np.mean(settled[start:start + size] ** 2)))
                       for start in range(0, len(settled) - size, size)]
        floor = 0.0001 if mode == "sand" else 0.003
        assert min(rms_windows) > floor
        item["minimum_settled_50ms_rms"] = min(rms_windows)
        if mode.startswith("wind"):
            previous, previous_rate = read(ROOT / "docs/evidence/desert-owner-wind-2026-10-10" / f"{mode}.wav")
            previous_rms = stats(previous, previous_rate)["rms"]
            item["db_gain_over_prior_native_sample"] = float(20 * np.log10(item["rms"] / previous_rms))
            assert item["db_gain_over_prior_native_sample"] > 3.0
        report["native"][mode] = item
    report["sand_db_below_wind"] = float(20 * np.log10(report["native"]["wind"]["rms"] / report["native"]["sand"]["rms"]))
    assert report["sand_db_below_wind"] > 6.0
    for mode in ["paused", "muted", "finished"]:
        values, rate = read(OUT / f"{mode}.wav")
        item = stats(values, rate)
        assert item["peak"] == 0
        report["silence"][mode] = item
    first = json.loads((OUT / "mixed0.json").read_text())
    second = json.loads((OUT / "mixed1.json").read_text())
    assert first != second and first["wind_variant"] != second["wind_variant"]
    assert len(first["gusts"]) >= 2 and len(second["gusts"]) >= 2
    report["variation"] = [first, second]
    report["controlled_vehicle_mix"] = {}
    for mode in ["stationary", "driving"]:
        values, rate = read(OUT / f"{mode}.wav")
        item = stats(values, rate)
        assert item["clipped"] == 0
        ambient, ambient_rate = read(OUT / f"{mode}-ambience.wav")
        engine, engine_rate = read(OUT / f"{mode}-engine.wav")
        assert ambient_rate == engine_rate == rate
        ambient_stats = stats(ambient, rate)
        engine_stats = stats(engine, rate)
        size = round(rate * 0.5)
        windows = [float(np.sqrt(np.mean(ambient[start:start + size] ** 2))) for start in range(round(rate), len(ambient) - size, size)]
        assert min(windows) > 0.01
        item.update(ambient=ambient_stats, engine=engine_stats, minimum_500ms_ambient_rms=min(windows))
        report["controlled_vehicle_mix"][mode] = item
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
