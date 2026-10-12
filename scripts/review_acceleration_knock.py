"""Review the native acceleration diagnostic without changing recorded assets."""
import hashlib
import json
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/acceleration-knock-2026-10-10"
capture = json.loads((OUT / "native-capture.json").read_text(encoding="utf-8"))
regression = json.loads((OUT / "regression.json").read_text(encoding="utf-8"))
assert capture["failures"] == regression["failures"] == 0
review = []
for report in capture["reports"]:
    name = f'{report["variant"]}-{report["fixture"]}.wav'
    with wave.open(str(OUT / name)) as wav:
        assert wav.getsampwidth() == 2
        rate, channels = wav.getframerate(), wav.getnchannels()
        data = wav.readframes(wav.getnframes())
    pcm = struct.unpack(f"<{len(data) // 2}h", data)
    peak = max(abs(x) for x in pcm)
    clipping = sum(abs(x) >= 32767 for x in pcm)
    tail_peak = max(abs(x) for x in pcm[-rate * channels // 2:])
    assert len(pcm) / channels / rate > 8.5 and 0 < peak < 32767
    assert clipping == tail_peak == 0
    events = report["events"]
    expected = report["variant"] == "before" and report["fixture"] == "acceleration"
    assert bool(events) == expected
    assert all(event["clip"] == "chassis" and event["pitch"] == 1.32 for event in events)
    times = [next(t["seconds"] for t in report["telemetry"] if t["tick"] > e["tick"]) for e in events]
    review.append({"file": name, "seconds": len(pcm) / channels / rate,
                   "peak": peak / 32768, "clipped_samples": clipping,
                   "paused_tail_peak": tail_peak, "body_events": len(events),
                   "body_event_seconds": times})
hashes = json.loads((OUT / "before-vehicle-wav-hashes.json").read_text(encoding="utf-8-sig"))
for path, expected in hashes.items():
    source = ROOT / "game/assets/audio/vehicles" / path
    assert hashlib.sha256(source.read_bytes()).hexdigest().lower() == expected.lower(), path
result = {"captures": review, "vehicle_sources_unchanged": len(hashes),
          "regression_checks": regression["checks"], "failures": 0,
          "limitations": "Synthetic driving presentation; diagnostic Godot body fallback. Exact owner/device sound unconfirmed."}
(OUT / "review.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
rows = []
for fixture in ["stationary", "acceleration"]:
    rows.append(f"<h2>{fixture.capitalize()}</h2>")
    for variant in ["before", "after"]:
        rows.append(f'<p>{variant.capitalize()}</p><audio controls preload="none" src="{variant}-{fixture}.wav"></audio>')
(OUT / "audition.html").write_text(
    '<!doctype html><meta charset="utf-8"><title>Acceleration knock comparison</title>'
    '<style>body{font:18px system-ui;max-width:720px;margin:40px auto;background:#121925;color:#f4f5f6}audio{width:100%}</style>'
    '<h1>Acceleration knock comparison</h1><p>Throttle starts at 1 second. Smooth acceleration reaches 24 m/s at 7 seconds. '
    'Pause at 8 seconds. Body cues use the existing Godot fallback for recording.</p>'
    + "".join(rows), encoding="utf-8")
print(json.dumps(result, indent=2))
