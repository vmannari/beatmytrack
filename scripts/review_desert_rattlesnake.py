"""Verify recorded rattles, native Desert mix continuity, timing and silent lifecycle."""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "game/assets/audio/ambience"
OUT = ROOT / "docs/evidence/desert-rattle-variation-2026-10-11"


def read(path):
    with wave.open(str(path), "rb") as wav:
        assert wav.getsampwidth() == 2
        rate, channels = wav.getframerate(), wav.getnchannels()
        values = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").reshape(-1, channels).astype(np.float64) / 32768
    return values, rate


def stats(values, rate):
    rms = float(np.sqrt(np.mean(values ** 2)))
    return dict(seconds=len(values) / rate, peak=float(np.max(np.abs(values))), rms=rms,
                rms_dbfs=float(20 * np.log10(rms)) if rms > 0 else None,
                clipped=int(np.count_nonzero(np.abs(values) >= 0.999)))


def main():
    manifest = json.loads((BANK / "desert_rattlesnake_manifest.json").read_text())
    source_dir = ROOT / "build/desert_rattlesnake/sources"
    assert hashlib.sha256((source_dir / "rattlesnake.ogg").read_bytes()).hexdigest() == manifest["source_sha256"]
    raw = (source_dir / "rattlesnake.f32").read_bytes()
    assert hashlib.sha256(raw).hexdigest() == manifest["decoded_sha256"]
    source = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    meta = json.loads((source_dir / "rattlesnake.decode.json").read_text())
    if meta["rate"] != 44100:
        positions = np.arange(round(len(source) * 44100 / meta["rate"]), dtype=np.float64) * meta["rate"] / 44100
        source = np.interp(positions, np.arange(len(source), dtype=np.float64), source)
    report = dict(masters=[], native={}, silence={}, events={})
    for clip in manifest["clips"]:
        path = BANK / clip["filename"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == clip["sha256"]
        values, rate = read(path)
        assert rate == 44100 and values.shape[1] == 1 and len(values) == clip["seconds"] * rate
        assert values[0, 0] == values[-1, 0] == 0
        item = stats(values, rate)
        assert item["clipped"] == 0 and item["rms"] > 0.08
        start = round(clip["source_start_seconds"] * rate)
        edge = round(0.05 * rate)
        original = source[start + edge:start + len(values) - edge]
        correlation = float(np.corrcoef(values[edge:-edge, 0], original)[0, 1])
        assert correlation > 0.99999
        item["source_waveform_correlation"] = correlation
        item["filename"] = path.name
        report["masters"].append(item)
    for mode in ["rattle_a", "rattle_b", "rattle_a_alt", "rattle_b_alt", "desert0", "desert1", "driving"]:
        values, rate = read(OUT / f"{mode}.wav")
        item = stats(values, rate)
        assert item["clipped"] == 0 and item["peak"] > 0.02
        if mode.startswith("desert"):
            n = round(rate * 0.5)
            settled = values[2 * rate:]
            windows = [float(np.sqrt(np.mean(settled[index:index + n] ** 2))) for index in range(0, len(settled) - n, n)]
            assert min(windows) > 0.01
            item["minimum_500ms_rms"] = min(windows)
        report["native"][mode] = item
        if mode.startswith(("desert", "rattle")) or mode == "driving":
            events = json.loads((OUT / f"{mode}.json").read_text())
            assert len(events) >= (2 if mode.startswith("desert") else 1)
            for previous, current in zip(events, events[1:]):
                length = previous["duration"]
                assert previous["variant"] != current["variant"]
                assert current["seconds"] - previous["seconds"] >= length + previous["gap"] - 0.15
            report["events"][mode] = events
            for event in events:
                assert 1.349 <= event["duration"] * event["pitch"] <= 3.251
                assert event["offset"] >= 0.05
                assert event["offset"] + event["duration"] * event["pitch"] <= manifest["clips"][event["variant"]]["seconds"] - 0.049
                assert len(event["rhythm_times"]) == len(event["rhythm_levels"]) >= 4
                assert all(a < b for a, b in zip(event["rhythm_times"], event["rhythm_times"][1:]))
                assert all(0.379 <= level <= 1 for level in event["rhythm_levels"])
    for variant in ["a", "b"]:
        first = report["events"][f"rattle_{variant}"][0]
        other = report["events"][f"rattle_{variant}_alt"][0]
        assert first["variant"] == other["variant"]
        assert all(first[key] != other[key] for key in ["offset", "duration", "rhythm_times", "rhythm_levels"])
        # Compare normalized audible envelopes aligned to onset. This detects
        # content-shape variation independently of waiting time or overall gain.
        shapes = []
        for mode in [f"rattle_{variant}", f"rattle_{variant}_alt"]:
            values, rate = read(OUT / f"{mode}.wav")
            n = round(0.025 * rate)
            envelope = np.array([np.sqrt(np.mean(values[i:i+n] ** 2)) for i in range(0, len(values)-n, n)])
            onset = np.flatnonzero(envelope > envelope.max() * 0.1)[0]
            shapes.append(envelope[onset:] / envelope.max())
        size = min(map(len, shapes))
        difference = float(np.mean(np.abs(shapes[0][:size] - shapes[1][:size])))
        assert difference > 0.04
        report["native"][f"rattle_{variant}"]["alternate_normalized_envelope_difference"] = difference
    assert report["events"]["desert0"] != report["events"]["desert1"]
    for mode in ["paused", "muted", "finished"]:
        values, rate = read(OUT / f"{mode}.wav")
        item = stats(values, rate)
        assert item["peak"] == 0
        report["silence"][mode] = item
    (OUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__": main()
