"""Measure native layer balance, variable mix evidence and silent lifecycle states."""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "game/assets/audio/ambience"
OUT = ROOT / "docs/evidence/grass-nature-2026-10-10"


def stats(path):
    with wave.open(str(path), "rb") as wav:
        assert wav.getsampwidth() == 2
        channels, rate = wav.getnchannels(), wav.getframerate()
        pcm = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").reshape(-1, channels)
    values = pcm.astype(np.float64) / 32768
    rms = float(np.sqrt(np.mean(values ** 2)))
    return dict(seconds=len(values) / rate, peak=float(np.max(np.abs(values))), rms=rms,
                rms_dbfs=float(20 * np.log10(rms)) if rms > 0 else None,
                clipping_samples=int(np.count_nonzero(np.abs(values) >= 0.999)))


def main():
    manifest = json.loads((BANK / "grass_nature_manifest.json").read_text())
    for filename, expected in [(manifest["filename"], manifest["sha256"]),
                               (manifest["insects"]["filename"], manifest["insects"]["sha256"])]:
        assert hashlib.sha256((BANK / filename).read_bytes()).hexdigest() == expected
    for clip in json.loads((BANK / "grass_birds_manifest.json").read_text())["clips"]:
        assert hashlib.sha256((BANK / clip["filename"]).read_bytes()).hexdigest() == clip["sha256"]
    report = {"layers": {}, "silence": {}, "variation": {}}
    for name in ["insects", "leaves", "birds", "mixed0", "mixed1"]:
        item = stats(OUT / f"{name}.wav")
        assert item["peak"] > 0.001 and item["clipping_samples"] == 0
        report["layers"][name] = item
    bird_rms = report["layers"]["birds"]["rms"]
    for name in ["insects", "leaves"]:
        level = report["layers"][name]
        level["db_below_birds"] = float(20 * np.log10(bird_rms / level["rms"]))
        assert level["db_below_birds"] > 7
    for name in ["paused", "muted", "finished"]:
        item = stats(OUT / f"{name}.wav")
        assert item["peak"] == 0
        report["silence"][name] = item
    first = json.loads((OUT / "mixed0.json").read_text())
    second = json.loads((OUT / "mixed1.json").read_text())
    assert first["insect_offset"] != second["insect_offset"] and first["rustles"] != second["rustles"]
    for events in [first, second]:
        assert events["rustles"]
        for previous, current in zip(events["rustles"], events["rustles"][1:]):
            assert current["seconds"] - previous["seconds"] >= manifest["seconds"] / previous["pitch"] + previous["gap"] - 0.15
    report["variation"] = {"race0": first, "race1": second}
    (OUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
