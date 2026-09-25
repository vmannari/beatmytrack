"""Offline, local WAV measurements only; does not listen or classify musical style.

Usage: python scripts/analyze_music_reference.py input.wav output.json
Requires the development environment's numpy; no game/runtime dependency.
"""
import argparse
import json
import wave
from pathlib import Path

import numpy as np


def analyze(path):
    with wave.open(str(path)) as reader:
        if reader.getsampwidth() != 2:
            raise ValueError("This diagnostic expects 16-bit PCM WAV")
        rate = reader.getframerate()
        channels = reader.getnchannels()
        pcm = np.frombuffer(reader.readframes(reader.getnframes()), dtype="<i2")
    pcm = pcm.reshape(-1, channels).astype(np.float32) / 32768.0
    mono = pcm.mean(axis=1)
    hop = round(rate / 100)
    frames = np.lib.stride_tricks.sliding_window_view(mono, 4096)[::hop]
    spectrum = np.abs(np.fft.rfft(frames * np.hanning(4096), axis=1))
    frequencies = np.fft.rfftfreq(4096, 1 / rate)
    power = (spectrum**2).sum(axis=0)
    onset = np.maximum(np.diff(np.log1p(spectrum[:, (frequencies > 35) & (frequencies < 8000)]), axis=0), 0).mean(axis=1)
    onset -= onset.mean()
    correlation = np.correlate(onset, onset, "full")[len(onset) - 1:]
    correlation /= max(correlation[0], 1e-12)
    candidates = [(round(60 * rate / hop / lag, 2), round(float(correlation[lag]), 3))
                  for lag in range(30, min(80, len(correlation) - 1))
                  if correlation[lag] > correlation[lag - 1] and correlation[lag] >= correlation[lag + 1]]
    result = {
        "seconds": len(pcm) / rate,
        "sample_rate": rate,
        "rms_db": float(20 * np.log10(max(np.sqrt(np.mean(pcm * pcm)), 1e-12))),
        "peak_db": float(20 * np.log10(max(np.abs(pcm).max(), 1e-12))),
        "bands": {f"{lo}-{hi}": float(power[(frequencies >= lo) & (frequencies < hi)].sum() / max(power.sum(), 1e-12))
                  for lo, hi in [(20, 150), (150, 500), (500, 2000), (2000, 6000), (6000, 16000)]},
        "tempo_candidates": sorted(candidates, key=lambda item: -item[1]),
        "limitations": "Onset periodicity is a tempo estimate. Band energy does not establish instrumentation, genre, musical quality or perceptual similarity.",
    }
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.write_text(json.dumps(analyze(args.input), indent=2) + "\n", encoding="utf-8")
