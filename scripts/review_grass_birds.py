"""Check source derivatives and optional native mixer evidence; writes a JSON report."""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "game/assets/audio/ambience"
OUT = ROOT / "docs/evidence/grass-birds-2026-10-10"


def read(path):
    with wave.open(str(path), "rb") as wav:
        rate, channels = wav.getframerate(), wav.getnchannels()
        assert wav.getsampwidth() == 2
        samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").reshape(-1, channels)
    return samples.astype(np.float64) / 32768.0, rate


def main():
    manifest = json.loads((BANK / "grass_birds_manifest.json").read_text())
    report = {"clips": [], "native": [], "silence": []}
    for item in manifest["clips"]:
        path = BANK / item["filename"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"]
        values, rate = read(path)
        assert rate == 44100 and values.shape[1] == 1
        assert np.max(np.abs(values)) < 0.51 and np.max(np.abs(values)) > 0.05
        assert values[0, 0] == values[-1, 0] == 0
        assert np.sqrt(np.mean(values ** 2)) > 0.06
        report["clips"].append(dict(filename=path.name, seconds=len(values) / rate,
                                    peak=float(np.max(np.abs(values))), sha256=item["sha256"]))
    events_by_race = []
    for race in range(2):
        path = OUT / f"race{race}.wav"
        if not path.exists():
            continue
        values, rate = read(path)
        events = json.loads((OUT / f"race{race}.json").read_text())
        assert len(events) >= 2
        assert 0.01 < np.max(np.abs(values)) < 0.4
        assert not np.any(np.abs(values) >= 0.999)
        # The gap begins after the previous complete phrase, with no overlap.
        for previous, current in zip(events, events[1:]):
            clip_seconds = manifest["clips"][previous["clip"]]["seconds"] / previous["pitch"]
            assert current["clip"] != previous["clip"]
            assert current["seconds"] - previous["seconds"] >= clip_seconds + previous["gap"] - 0.15
        events_by_race.append(events)
        report["native"].append(dict(filename=path.name, seconds=len(values) / rate,
                                     peak=float(np.max(np.abs(values))), events=len(events)))
    if len(events_by_race) == 2:
        assert events_by_race[0] != events_by_race[1]
    for mode in ["paused", "muted", "finished"]:
        path = OUT / f"{mode}.wav"
        if not path.exists():
            continue
        values, rate = read(path)
        assert np.max(np.abs(values)) == 0
        report["silence"].append(dict(mode=mode, seconds=len(values) / rate, peak=0))
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "review.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
