"""Verify actual own-process output gains, silence, stereo/pitch and sustained bounds."""
import csv
import json
from pathlib import Path
import sys
import wave

import numpy as np

out = Path(sys.argv[1]).resolve()
samples = np.frombuffer((out / "loopback.pcm").read_bytes(), dtype="<i2").reshape(-1, 2).astype(float) / 32768
with (out / "packets.csv").open() as handle:
    packets = list(csv.DictReader(handle))
controls = json.loads((out / "controls.json").read_text())
checks = []


def check(condition, label, **data):
    checks.append(dict(passed=bool(condition), check=label, **data))


def window(start, end):
    chunks = []
    for packet in packets:
        if int(packet["flags"]) & 4:
            continue
        offset, count = int(packet["frame_offset"]), int(packet["frames"])
        times = float(packet["utc_us"]) + np.arange(count) / 48000 * 1e6
        indexes = (times >= start) & (times < end)
        if indexes.any():
            chunks.append(samples[offset:offset + count][indexes])
    return np.concatenate(chunks)


levels = {}
segments = {}
for row in controls:
    # Allow both RAW and deliberately restored normal output to settle.
    values = window(row["unix_us"] + 300000, row["unix_us"] + 700000)
    segments[row["stage"]] = values
    levels[row["stage"]] = float(np.sqrt(np.mean(values ** 2)))
    check(len(values) >= 18000, row["stage"] + " has valid timestamped output", frames=len(values))

full = levels["full"]
check(full > .02, "reference output is audible", rms=full)
for label in ["master_half", "vehicle_half", "tires_half"]:
    ratio = levels[label] / full
    check(abs(ratio - .5) < .025, label + " applies gain exactly once", ratio=ratio)
for label in ["master_mute", "vehicle_mute", "tires_mute", "engine_mute", "music_mute", "interface_mute", "solo_excludes"]:
    check(levels[label] < .0001, label + " reaches actual silence", rms=levels[label])
for label in ["engine", "music", "interface", "solo_includes", "restored"]:
    ratio = levels[label] / full
    check(abs(ratio - 1) < .035, label + " retains original level without a duplicate copy", ratio=ratio)
ratio = levels["normal_fallback"] / levels["normal_reference"]
check(abs(ratio - 1) < .035, "fallback matches the original Godot/Windows output, including its OS processing", ratio=ratio)

# Compare channel peaks and sine amplitudes with the exact 16-bit test PCM.
values = segments["full"]
time = np.arange(len(values)) / 48000
for channel, frequencies, amplitudes in [(0, [431, 719], [.12, .04]), (1, [613, 997], [.09, .03])]:
    for frequency, amplitude in zip(frequencies, amplitudes):
        measured = float(abs(np.sum(values[:, channel] * np.exp(-2j * np.pi * frequency * time))) * 2 / len(time))
        check(abs(measured / amplitude - 1) < .035, "stereo PCM retains frequency and amplitude", channel=channel, frequency_hz=frequency, measured=measured, expected=amplitude)
    other = 613 if channel == 0 else 431
    leakage = float(abs(np.sum(values[:, channel] * np.exp(-2j * np.pi * other * time))) * 2 / len(time))
    check(leakage < .001, "channels remain separate", channel=channel, leakage=leakage)

stats = json.loads((out / "output-stats.json").read_text())
check(stats["ready"] and not stats["failed"] and stats["overflows"] == 0, "sustained real driving mix uses native output without overflow", stats=stats)
check(stats["buffer_bytes"] == 32768 and stats["peak_queued_frames"] <= 4096, "fixed 32 KiB transfer bounds are retained")
with wave.open(str(out / "pre-fader.wav")) as recording:
    check(recording.getnframes() > 48000 * 14, "recorder before final transfer retains the original mix", frames=recording.getnframes())
test = json.loads((out / "test-report.json").read_text())
check(test["failures"] == 0, "native lifecycle/rate/fallback assertions pass", test=test)
report = dict(process_only=True, microphone=False, other_application_audio=False, checks=checks,
              failures=sum(not row["passed"] for row in checks), levels=levels,
              limits="Windows process-loopback, before physical speakers/headphones/Bluetooth.")
(out / "control-report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
raise SystemExit(1 if report["failures"] else 0)
