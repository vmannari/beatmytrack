"""Check shipped cicada PCM and captured native playback/silence evidence."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "game/assets/audio/ambience"
OUT = ROOT / "docs/evidence/night-cicadas-loop-2026-10-10"
checks = 0


def check(ok, message):
    global checks
    checks += 1
    if not ok: raise AssertionError(message)


def read(path):
    with wave.open(str(path), "rb") as wav:
        check(wav.getsampwidth() == 2, str(path) + " must be 16-bit PCM")
        rate, channels = wav.getframerate(), wav.getnchannels()
        pcm = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2")
    return pcm.astype(np.float64).reshape(-1, channels) / 32768, rate


manifest = json.loads((BANK / "manifest.json").read_text())
source = BANK / "night_cicadas.wav"
check(hashlib.sha256(source.read_bytes()).hexdigest() == manifest["sha256"], "asset hash")
check(manifest["license"] == "CC0-1.0" and manifest["author"] == "Clarisse", "provenance")
pcm, rate = read(source)
check(rate == 44100 and pcm.shape == (40 * rate, 1), "bounded extended mono source")
check(abs(20 * np.log10(np.sqrt(np.mean(pcm ** 2))) + 22) < 0.01, "authored background RMS")
check(np.max(np.abs(pcm)) < 0.502, "source headroom")
check(abs(pcm[-1, 0] - pcm[0, 0]) < np.quantile(np.abs(np.diff(pcm[:, 0])), 0.99), "loop seam below ordinary recorded steps")


def overlap_metrics(samples, hz, seconds):
    block = hz // 4
    tail = samples[-round(seconds * hz):]
    envelope = np.sqrt(np.mean(tail.reshape(-1, block, samples.shape[1]) ** 2, axis=(1, 2)))
    rms = np.sqrt(np.mean(samples ** 2))
    return dict(seconds=len(samples) / hz, rms_dbfs=float(20 * np.log10(rms)),
                overlap_minimum_250ms_db_relative=float(20 * np.log10(np.min(envelope) / rms)))


before, before_rate = read(OUT / "before/game__assets__audio__ambience__night_cicadas.wav")
previous = overlap_metrics(before, before_rate, 1)
current = overlap_metrics(pcm, rate, manifest["overlap_seconds"])
check(current["seconds"] > 2 * previous["seconds"], "more than double the natural recording before repetition")
check(abs(current["rms_dbfs"] - previous["rms_dbfs"]) < 0.01, "retains background loudness")
check(current["overlap_minimum_250ms_db_relative"] > -1.5, "overlap has no pronounced periodic volume dip")
check(current["overlap_minimum_250ms_db_relative"] > previous["overlap_minimum_250ms_db_relative"] + 2,
      "at least 2dB reduction of the old crossfade dip")
rows = []
for name in ["cicadas-two-wraps", "paused", "muted", "finished"]:
    samples, hz = read(OUT / (name + ".wav"))
    seconds = len(samples) / hz
    peak = float(np.max(np.abs(samples)))
    rms = float(np.sqrt(np.mean(samples ** 2)))
    row = dict(name=name, rate=hz, channels=samples.shape[1], seconds=seconds, peak=peak, rms=rms)
    if name == "cicadas-two-wraps":
        check(seconds > 80, "capture covers two complete source loops")
        check(peak < 0.5 and rms > 0.02, "native output audible with headroom")
        window = hz // 10
        blocks = samples[:len(samples) // window * window].reshape(-1, window, samples.shape[1])
        minimum = float(np.min(np.sqrt(np.mean(blocks ** 2, axis=(1, 2)))))
        check(minimum > 0.01, "no silent 100ms dropouts through native loop boundaries")
        row["minimum_100ms_rms"] = minimum
    else:
        check(seconds > 0.25 and peak == 0, name + " is digitally silent after drain")
    rows.append(row)
result = dict(checks=checks, failures=0, previous=previous, current=current, captures=rows)
(OUT / "pcm-review.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
