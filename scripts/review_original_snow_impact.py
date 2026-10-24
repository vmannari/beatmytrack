"""Compare original snow entries and actual mastered event captures."""
import hashlib
import json
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/original-snow-impact-2026-10-23"
BANK = ROOT / "game/assets/audio/vehicles"
checks = []


def check(ok, label):
    checks.append(dict(passed=bool(ok), check=label))


def read(path):
    with wave.open(str(path), "rb") as stream:
        rate = stream.getframerate()
        values = np.frombuffer(stream.readframes(stream.getnframes()), "<i2").reshape(-1, stream.getnchannels()).astype(float) / 32768
    return values, rate


def db(values):
    return float(20 * np.log10(max(1e-10, np.sqrt(np.mean(values ** 2)))))


def metrics(path):
    stereo, rate = read(path)
    values = stereo.mean(axis=1)
    peak = float(abs(values).max())
    hz = np.fft.rfftfreq(len(values), 1 / rate)
    body = np.fft.irfft(np.fft.rfft(values) * ((hz >= 50) & (hz <= 580)), n=len(values))
    return dict(rate=rate, seconds=len(values) / rate, peak=peak, rms_dbfs=db(values),
                early_100ms_dbfs=db(values[:round(rate * .1)]), body_150ms_dbfs=db(body[:round(rate * .15)]),
                strong_onset_ms=float(np.flatnonzero(abs(values) >= peak * .5)[0] / rate * 1000),
                sha256=hashlib.sha256(path.read_bytes()).hexdigest())


before = OUT / "before/game/assets/audio/vehicles/snow_hit.wav"
files = {"before": before, **{name: ROOT / f"build/original-snow-impact-2026-10-23/variants/{name}.wav" for name in ["packed", "powder", "bank"]}}
rows = {name: metrics(path) for name, path in files.items()}
for name in ["packed", "powder", "bank"]:
    row = rows[name]
    check(row["rate"] == 44100 and row["peak"] <= .87 and row["seconds"] <= .5, name + " is portable, short and has headroom")
    check(row["strong_onset_ms"] <= 5, name + " retains a prompt strong attack")
    check(row["early_100ms_dbfs"] - rows["before"]["early_100ms_dbfs"] >= 1.5, name + " has a stronger first compression")
check(rows["packed"]["body_150ms_dbfs"] - rows["before"]["body_150ms_dbfs"] >= 1.5, "installed entry has more recorded low-body weight")
check(len({row["sha256"] for row in rows.values()}) == 4, "all three original options differ from each other and the old cue")
check(hashlib.sha256((BANK / "snow_hit.wav").read_bytes()).hexdigest() == rows["packed"]["sha256"], "balanced packed-snow option is installed")
check((BANK / "snow.wav").read_bytes() == (OUT / "before/game/assets/audio/vehicles/snow.wav").read_bytes(), "continuous plough loop remains byte exact")
manifest = json.loads((BANK / "snow_manifest.json").read_text())
check(manifest["reference_audio_used"] is False and all(row["license"] == "CC0-1.0" for row in manifest["sources"]), "only existing cleared sources are used")
for source in manifest["sources"]:
    path = ROOT / "build/vehicle_audio_sources/snow" / source["filename"]
    check(hashlib.sha256(path.read_bytes()).hexdigest() == source["sha256"], "source identity retained: " + source["filename"])

captured = {}
for name in files:
    values, rate = read(OUT / "audition" / (name + ".wav"))
    envelope = abs(values).max(axis=1)
    onset = int(np.flatnonzero(envelope > .01)[0])
    captured[name] = dict(peak=float(envelope.max()), onset_seconds=onset / rate,
                          early_100ms_dbfs=db(values[onset:onset + round(rate * .1)]))
    check(captured[name]["peak"] < .95 and captured[name]["peak"] > .1, name + " actual event is audible without clipping")
    check(float(abs(values[-round(rate * .1):]).max()) == 0, name + " event settles to exact silence")
check(captured["packed"]["early_100ms_dbfs"] - captured["before"]["early_100ms_dbfs"] >= 1.5, "actual mastered packed entry is stronger than the previous cue")

driving, driving_rate = read(OUT / "driving/driving.wav")
snow, snow_rate = read(OUT / "driving/snow.wav")
unwanted, _ = read(OUT / "driving/unwanted.wav")
check(float(abs(driving).max()) < .95, "full driving mix retains headroom")
check(float(abs(unwanted).max()) == 0, "snowbank entry produces no grass/sand/concrete audio")
for label, start, end in [("clear ice", .5, 1.5), ("leaving the bank", 11.3, 11.8), ("pause", 13.3, 13.8)]:
    check(float(abs(snow[round(start * snow_rate):round(end * snow_rate)]).max()) == 0, label + " retains exact snow silence")
check(float(abs(snow[round(2.1 * snow_rate):round(2.5 * snow_rate)]).max()) > .02, "real bank entry is audible")
check(db(snow[4 * snow_rate:9 * snow_rate]) > -40, "continuous bank ploughing remains audible")

report = dict(samples=rows, native_master_captures=captured, checks=checks,
              failures=sum(not row["passed"] for row in checks),
              reference="Soundsnap search metadata only. Its public player returned unusable identical clips; no claim to have heard those recordings. No Soundsnap audio appears in these composites.",
              scope="Actual Godot event pool at the same .65 gain/.90 pitch and original Vehicle/Master processing. Audition uses ordinary event routing for recording, separate native regressions verify RAW playback.")
(OUT / "analysis.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

# One short listening strip: previous, packed, powder, bank; two hits per choice.
strip = []
for name in files:
    values, rate = read(OUT / "audition" / (name + ".wav"))
    strip.extend([values, np.zeros((round(rate * .2), values.shape[1])), values, np.zeros((round(rate * .65), values.shape[1]))])
values = np.concatenate(strip)
with wave.open(str(OUT / "comparison.wav"), "wb") as stream:
    stream.setparams((values.shape[1], 2, rate, len(values), "NONE", "not compressed"))
    stream.writeframes(np.round(np.clip(values, -1, 1) * 32767).astype("<i2").tobytes())
print("ORIGINAL_SNOW_ANALYSIS:", len(checks), "checks,", report["failures"], "failures")
print("EARLY_COMPRESSION_GAIN_DB:", captured["packed"]["early_100ms_dbfs"] - captured["before"]["early_100ms_dbfs"])
if report["failures"]: raise SystemExit(1)
