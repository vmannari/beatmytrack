"""Original, sample-performed chamber score; exact additive stems and circular tails.

Run with scripts/render_score_v1.sh in the existing local audio environment.
No generated mixes, realtime synthesis, external runtime or borrowed melodies.
Source WAVs are immutable CC0 recordings, checked against the pinned manifest.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
from functools import lru_cache
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import numpy as np
import scipy
from scipy.signal import butter, resample_poly, sosfilt
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "build/music/score-v1/sources"
MASTERS = ROOT / "build/music/score-v1/masters"
OUTPUT = ROOT / "build/music/score-v1/exports-v2"
EVIDENCE = ROOT / "docs/evidence/adaptive-score-2026-10-07"
RATE = 44100
BPM = 120
BARS = 32
BEATS = BARS * 4
FRAMES = RATE * 64
LAYER_NAMES = ["foundation", "current", "motion", "flight", "arrival"]
FFMPEG = os.environ.get("BMT_SCORE_FFMPEG", "ffmpeg")
REVISION = 2
UPBEAT = False
MENU_BPM = 90
SOURCE_MANIFEST = json.loads((SOURCE / "manifest.json").read_text())
SOURCE_MAP = {item["path"]: item for item in SOURCE_MANIFEST["sources"] if item["path"].endswith(".wav")}


def midi(note):
    match = re.fullmatch(r"([A-G])([#b]?)(-?\d+)", note)
    letter, accidental, octave = match.groups()
    return 12 * (int(octave) + 1) + {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[letter] + {"": 0, "#": 1, "b": -1}[accidental]


def pitch_from_name(path):
    match = re.search(r"_([A-G]#?\d)_", Path(path).name)
    # Bowed/wind folders use middle C = C3; piano/harp use C4. Measured per source family.
    if not match: return 60
    octave_offset = 0 if "Upright Nr1" in path or "/Harp/" in path else 12
    return midi(match.group(1)) + octave_offset


@lru_cache(maxsize=None)
def recording(path):
    source = SOURCE / path
    assert hashlib.sha256(source.read_bytes()).hexdigest() == SOURCE_MAP[path]["sha256"]
    pcm, rate = sf.read(source, dtype="float64", always_2d=True)
    assert np.isfinite(pcm).all() and np.max(np.abs(pcm)) > 0.0001
    if rate != RATE:
        divisor = math.gcd(rate, RATE)
        pcm = resample_poly(pcm, RATE // divisor, rate // divisor, axis=0)
    # Retain natural stereo but narrow the library's varying mic positions.
    if pcm.shape[1] == 1:
        pcm = np.repeat(pcm, 2, axis=1)
    pcm = pcm[:, :2]
    mono = pcm.mean(axis=1, keepdims=True)
    pcm = mono + (pcm - mono) * 0.32
    active = np.max(np.abs(pcm), axis=1)
    onset = int(np.argmax(active > max(0.00008, float(active.max()) * 0.012)))
    pcm = pcm[max(0, onset - int(RATE * 0.008)):]
    pcm -= pcm.mean(axis=0)
    rms = float(np.sqrt(np.mean(pcm[:min(len(pcm), RATE * 2)] ** 2)))
    # Per-instrument balance lives in the written score. Normalize source capture level only.
    return pcm * min(4.0, 0.11 / max(rms, 0.004))


def instrument(path):
    if "Upright Nr1" in path: return "piano"
    if "Cello Section" in path: return "cello"
    if "Violin Section" in path: return "violin"
    if "Viola Section" in path: return "viola"
    if "Harp" in path: return "harp"
    if "/Flute/" in path: return "flute"
    if "F Horn" in path: return "horn"
    if "LogDrum" in path: return "log"
    if "Conga" in path: return "tap"
    if "BDrum" in path: return "bass_drum"
    raise ValueError(path)


POOLS = {kind: sorted(path for path in SOURCE_MAP if instrument(path) == kind)
         for kind in ["piano", "cello", "violin", "viola", "harp", "flute", "horn", "log", "tap", "bass_drum"]}


@lru_cache(maxsize=1024)
def performed(kind, pitch, duration_frames, variation):
    pool = POOLS[kind]
    pitched = kind not in ["log", "tap", "bass_drum"]
    nearest = min(abs(pitch_from_name(path) - pitch) for path in pool) if pitched else 0
    choices = [path for path in pool if not pitched or abs(pitch_from_name(path) - pitch) == nearest]
    path = choices[variation % len(choices)]
    original = recording(path)
    ratio = 2 ** ((pitch - pitch_from_name(path)) / 12) if pitched else 1.0
    # Bandlimited sample-rate conversion, with a rational rate to avoid int32 coordinates.
    denominator = 4096
    numerator = round(denominator / ratio)
    divisor = math.gcd(numerator, denominator)
    pcm = resample_poly(original, numerator // divisor, denominator // divisor, axis=0)
    sustained = kind in ["cello", "viola", "violin", "flute", "horn"]
    release = int(RATE * (0.42 if sustained else 0.7))
    count = duration_frames + release
    if sustained and len(pcm) < count:
        # Crossfade a measured stable sustain region only if a long note exhausts the take.
        start, end = int(len(pcm) * 0.28), int(len(pcm) * 0.74)
        region = pcm[start:end]
        cross = min(int(RATE * 0.16), len(region) // 4)
        while len(pcm) < count:
            fade = np.linspace(0, 1, cross)[:, None]
            pcm = np.concatenate([pcm[:-cross], pcm[-cross:] * (1 - fade) + region[:cross] * fade, region[cross:]])
    pcm = np.pad(pcm[:count], ((0, max(0, count - len(pcm))), (0, 0)))
    if sustained:
        attack = min(duration_frames // 3, int(RATE * (0.18 if kind == "flute" else 0.27)))
        pcm[:attack] *= np.sin(np.linspace(0, np.pi / 2, attack))[:, None] ** 2
        # Phrase-shaped bow/breath expression, rather than an unchanging held sample.
        phrase = 0.79 + 0.21 * np.sin(np.linspace(0, np.pi, duration_frames))
        pcm[:duration_frames] *= phrase[:, None]
    else:
        attack = min(int(RATE * 0.009), len(pcm))
        pcm[:attack] *= np.linspace(0, 1, attack)[:, None]
    pcm[-release:] *= np.cos(np.linspace(0, np.pi / 2, release))[:, None] ** 2
    return pcm


class Score:
    def __init__(self, bpm=120, bars=32):
        self.bpm = bpm
        self.frames = round(bars * 4 * 60 / bpm * RATE)
        self.audio = [np.zeros((self.frames, 2), dtype=np.float64) for _ in LAYER_NAMES]
        self.events = []

    def note(self, layer, kind, pitch, beat, length, gain, pan=0.0):
        index = len(self.events)
        # Small deterministic performance offsets, fixed in the source score, never runtime RNG.
        offset = (0.004 * math.sin(index * 1.73)) if kind in ["piano", "harp", "tap", "log"] else 0.0
        start = round((beat * 60 / self.bpm + offset) * RATE)
        duration = max(32, round(length * 60 / self.bpm * RATE))
        sample = performed(kind, pitch, duration, index) * gain * (1 + 0.035 * math.sin(index * 0.71))
        left, right = math.sqrt(1 - pan) / math.sqrt(2), math.sqrt(1 + pan) / math.sqrt(2)
        sample = sample * np.array([left, right])
        # Wrap note releases from the end of the score into its opening, without edge fades/silence.
        start %= self.frames
        first = min(len(sample), self.frames - start)
        self.audio[layer][start:start + first] += sample[:first]
        if first < len(sample): self.audio[layer][:len(sample) - first] += sample[first:]
        self.events.append({"layer": LAYER_NAMES[layer], "instrument": kind, "midi": pitch,
                            "beat": beat, "length_beats": length, "gain": gain, "pan": pan})


# A composed 32-bar arc: statement, answer, departure and expanded return.
# Harmony uses two-bar blocks, intentionally including suspensions and ninths.
CHORDS = [
    (50, [57, 62, 65, 69]), (46, [53, 57, 60, 65]),
    (53, [60, 65, 69, 72]), (48, [55, 60, 62, 67]),
    (43, [50, 57, 58, 62]), (46, [53, 57, 60, 65]),
    (53, [57, 60, 65, 67]), (48, [55, 60, 62, 64]),
    (46, [53, 57, 60, 65]), (48, [55, 60, 64, 67]),
    (50, [57, 62, 65, 69]), (45, [52, 57, 62, 64]),
    (43, [50, 57, 58, 62]), (46, [53, 57, 60, 65]),
    (48, [55, 60, 62, 67]), (50, [57, 62, 64, 69]),
]
MELODY = [
    [(0, 62, 2.6), (3, 65, 1.3), (5, 69, 2.4)],
    [(0, 69, 2), (2.5, 67, 1.2), (4, 65, 3.4)],
    [(0, 65, 2.5), (3, 67, 1.3), (5, 69, 2.3)],
    [(0, 67, 2.6), (3.5, 64, 1.3), (5.5, 62, 2.0)],
    [(0, 62, 3.4), (4, 65, 1.6), (6, 67, 1.5)],
    [(0, 65, 2.6), (3, 62, 1.4), (5, 60, 2.5)],
    [(0, 60, 2.6), (3, 65, 1.5), (5, 69, 2.4)],
    [(0, 67, 2.6), (3, 64, 1.4), (5, 62, 2.4)],
    [(0, 65, 2.5), (3, 69, 1.5), (5, 72, 2.5)],
    [(0, 71, 1.5), (2, 69, 1.5), (4, 67, 3.4)],
    [(0, 69, 3.3), (4, 65, 1.4), (6, 64, 1.5)],
    [(0, 64, 2.5), (3, 62, 1.5), (5, 61, 2.5)],
    [(0, 62, 2.5), (3, 65, 1.3), (5, 69, 2.4)],
    [(0, 69, 2.5), (3, 67, 1.3), (5, 65, 2.4)],
    [(0, 67, 2.3), (3, 64, 1.3), (5, 62, 2.6)],
    [(0, 64, 2.3), (3, 65, 1.3), (5, 62, 2.6)],
]


def transform(pitch, daylight):
    # The second concept is a D-major modal response to the same melodic contour.
    if daylight and pitch % 12 in [5, 10]: return pitch + 1
    return pitch


def compose(daylight=False, menu=False):
    if UPBEAT: return compose_upbeat(daylight, menu)
    score = Score(90 if menu else BPM)
    for block, (root, chord) in enumerate(CHORDS):
        at = block * 8
        root = transform(root, daylight)
        chord = [transform(n, daylight) for n in chord]
        # Foundation carries its own identity and phrase movement, even without any earned layers.
        score.note(0, "cello", root, at, 3.2, 0.20 if menu else 0.22, 0.1)
        score.note(0, "cello", root, at + 4, 3.3, 0.16 if menu else 0.18, 0.1)
        for n, pitch in enumerate(chord[:3]):
            score.note(0, "piano", pitch - 12, at + n * 0.065, 3.4, 0.14, -0.12)
            score.note(0, "piano", pitch - 12, at + 4 + n * 0.045, 3.1, 0.10, -0.12)
        for beat, pitch, length in MELODY[block]:
            pitch = transform(pitch, daylight)
            score.note(0, "piano", pitch, at + beat, length, 0.24 if menu else 0.22, -0.04)
            if menu and block % 4 in [1, 3]:
                score.note(0, "viola", pitch - 12, at + beat + 0.03, length, 0.055, -0.18)
        if menu:
            for beat, note_index in [(1, 0), (3, 1), (6, 2)]:
                score.note(0, "harp", chord[note_index], at + beat, 1.6, 0.09, 0.18)
            if block % 4 == 2:
                score.note(0, "flute", chord[1], at + 4, 2.8, 0.055, 0.10)
            continue
        # Current: a low/mid harp pattern with a different answer every second phrase.
        for beat, note_index in [(0.5, 0), (2, 1), (3.5, 2), (5, 1), (6.5, 3)]:
            score.note(1, "harp", chord[note_index], at + beat, 1.3, 0.17 if daylight else 0.13, -0.27)
        # Motion: bowed movement and understated hand percussion, with breathing bars.
        for beat in [0, 1.5, 3, 4, 5.5, 7]:
            pitch = chord[0] - 12 if beat in [0, 3, 4, 7] else chord[1] - 12
            score.note(2, "viola", pitch, at + beat, 0.8, 0.11, -0.23)
        for beat, gain in [(0, 0.10), (3, 0.07), (4, 0.09), (6.5, 0.06)]:
            if block % 4 == 3 and beat > 4: continue
            score.note(2, "log", 60, at + beat, 0.5, gain, 0.10)
        for beat in ([1.75, 5.75] if daylight else [2.5, 6.0]):
            score.note(2, "tap", 60, at + beat, 0.35, 0.05, -0.1)
        # Flight: a answering voice, not a competing second lead over every melody note.
        answer = [chord[1], chord[2], chord[1], chord[3]][block % 4]
        score.note(3, "flute", answer, at + 1.5, 2.1, 0.105 if daylight else 0.075, 0.24)
        score.note(3, "horn", chord[0], at + 4.2, 2.4, 0.060, 0.14)
        # Arrival unfolds the already-known theme in the strings, with a shaped long-note payoff.
        for beat, pitch, length in MELODY[block]:
            pitch = transform(pitch, daylight)
            score.note(4, "violin", pitch, at + beat + 0.03, length, 0.18, -0.12)
        score.note(4, "horn", chord[2] - 12, at, 3.2, 0.07, 0.22)
        score.note(4, "bass_drum", 60, at, 0.6, 0.075, 0.0)
    return score


UPBEAT_CHORDS = [
    (50, [57, 62, 66, 69]), (43, [55, 59, 62, 67]),
    (45, [57, 61, 64, 69]), (50, [57, 62, 66, 69]),
    (50, [57, 62, 66, 69]), (43, [55, 59, 62, 67]),
    (50, [54, 57, 62, 66]), (45, [57, 61, 64, 69]),
    (43, [55, 59, 62, 67]), (50, [57, 62, 66, 69]),
    (45, [57, 61, 64, 69]), (50, [57, 62, 66, 69]),
    (43, [55, 59, 62, 67]), (45, [57, 61, 64, 69]),
    (50, [57, 62, 66, 69]), (45, [57, 61, 64, 69]),
]
# Rising statements and answering landings; 4-bar sentences develop a recurring
# D-F#-A gesture. Mid register keeps the quicker articulation from becoming shrill.
UPBEAT_MELODY = [
    [(0,62,.7),(1,66,.6),(1.75,69,.8),(3,66,.65),(4,64,.6),(5,66,.65),(6,69,1.3)],
    [(0,67,.8),(1.5,69,.6),(2.5,71,.75),(4,69,.6),(5,67,.65),(6.25,66,1.2)],
    [(0,64,.8),(1,66,.6),(2,69,.75),(3.5,66,.6),(4.5,64,.6),(6,61,1.3)],
    [(0,62,1.0),(1.5,66,.6),(2.5,69,.75),(4,66,.7),(5.5,64,.65),(6.5,62,1.1)],
    [(0,62,.65),(1,66,.6),(1.75,69,.7),(3,71,.65),(4,69,.7),(5.5,66,.65),(6.5,69,1.1)],
    [(0,67,.75),(1.25,71,.6),(2.25,69,.65),(3.5,67,.7),(5,66,.65),(6,62,1.2)],
    [(0,66,.75),(1.5,69,.6),(2.5,71,.65),(4,69,.65),(5,66,.65),(6.25,64,1.1)],
    [(0,64,.75),(1.5,66,.65),(2.5,69,.75),(4.25,64,.65),(5.5,61,.65),(6.5,62,1.1)],
    [(0,67,.75),(1.5,71,.65),(2.5,69,.7),(4,67,.75),(5.5,66,.65),(6.5,62,1.1)],
    [(0,66,.75),(1,69,.6),(2,71,.7),(3.5,69,.65),(4.5,66,.65),(6,62,1.3)],
    [(0,64,.8),(1.5,69,.65),(2.5,66,.7),(4,64,.75),(5.5,61,.65),(6.5,64,1.1)],
    [(0,62,.75),(1,66,.6),(2,69,.75),(3.5,71,.6),(4.5,69,.7),(6,66,1.3)],
    [(0,67,.75),(1.5,71,.65),(2.5,69,.7),(4,67,.75),(5.5,66,.6),(6.5,67,1.1)],
    [(0,69,.8),(1.5,66,.65),(2.5,64,.7),(4,66,.75),(5.5,69,.65),(6.5,61,1.1)],
    [(0,62,.7),(1,66,.6),(1.75,69,.8),(3,71,.65),(4,69,.7),(5.5,66,.65),(6.5,62,1.1)],
    [(0,64,.75),(1.5,66,.65),(2.5,69,.75),(4,66,.7),(5.5,64,.65),(6.5,61,1.1)],
]


def compose_upbeat(daylight=False, menu=False):
    score = Score(MENU_BPM if menu else BPM)
    for block, (root, chord) in enumerate(UPBEAT_CHORDS):
        at = block * 8
        # Rhythmic foundation from the opening; no long minor/cello-pad intro.
        for beat in [0, 2, 4, 6]:
            score.note(0, "cello", root, at + beat, 1.35, .13, .08)
            score.note(0, "piano", root, at + beat, .8, .12, -.08)
        for beat in [0, 1.5, 2.5, 4, 5.5, 6.5]:
            for n, pitch in enumerate(chord[:3]):
                score.note(0, "piano", pitch - 12, at + beat + n * .025, .7, .080, -.1)
        for beat, pitch, length in UPBEAT_MELODY[block]:
            score.note(0, "piano", pitch, at + beat, length, .21 if menu else .19, -.04)
        for beat in [1, 3, 5, 7]:
            if block % 4 == 3 and beat == 7: continue
            score.note(0, "tap", 60, at + beat, .3, .035 if menu else .045, .08)
        if menu:
            for beat, note_index in [(.75,0),(2.75,2),(4.75,1),(6.75,2)]:
                score.note(0, "harp", chord[note_index], at + beat, .8, .07, .18)
            if block % 4 == 2:
                score.note(0, "flute", chord[1], at + 6, 1.25, .055, .1)
            continue
        # Two instrumental colours of this same upbeat family, on the same clock.
        for beat, note_index in [(.75,0),(1.5,1),(2.75,2),(4.75,1),(5.5,2),(6.75,3)]:
            score.note(1, "harp", chord[note_index], at + beat, .85, .14 if daylight else .12, -.24)
        if daylight:
            score.note(1, "piano", chord[2], at + 3.5, .7, .06, .2)
        # Earned motion adds a light acoustic backbeat and bowed offbeat answers.
        for beat in [0, 2, 4, 6]:
            score.note(2, "bass_drum", 60, at + beat, .45, .065, 0.0)
        for beat in [1, 3, 5, 7]:
            score.note(2, "log", 60, at + beat, .4, .07, .06)
            if beat != 7 or block % 4 != 3:
                score.note(2, "tap", 60, at + beat + .5, .25, .035, -.08)
        for beat, note_index in [(.75,0),(2.25,1),(3.5,0),(4.75,0),(6.25,1)]:
            score.note(2, "viola", chord[note_index] - 12, at + beat, .9, .095, -.2)
        # Brief lifted answers replace the sustained wistful wind/horn colour.
        for beat, note_index in [(2.5,1),(6.5,2)]:
            score.note(3, "flute", chord[note_index], at + beat, 1.1, .075, .2)
        score.note(3, "horn", chord[0], at + 4.25, 1.4, .055, .12)
        # Expanded, familiar motif at arrival; preserve some phrase breathing room.
        for beat, pitch, length in UPBEAT_MELODY[block]:
            score.note(4, "violin", pitch, at + beat + .025, length * 1.15, .15, -.1)
        for beat in [0, 4]:
            score.note(4, "horn", chord[2] - 12, at + beat, 1.8, .055, .18)
    return score


def room(pcm):
    # Circular, stereo room response: tails from the prior cycle are present at frame zero.
    # It is baked into each source layer, requiring no realtime effects or extra voices.
    pcm = sosfilt(butter(2, 90, "highpass", fs=RATE, output="sos"), np.tile(pcm, (2, 1)), axis=0)[len(pcm):]
    pcm = sosfilt(butter(2, 6500, "lowpass", fs=RATE, output="sos"), np.tile(pcm, (2, 1)), axis=0)[len(pcm):]
    wet = np.zeros_like(pcm)
    for i in range(22 if UPBEAT else 32):
        delay = round(RATE * (0.032 + i * 0.039 + 0.009 * math.sin(i * 2.1)))
        gain = (0.024 if UPBEAT else 0.036) * math.exp(-i / 9.0)
        shifted = np.roll(pcm, delay, axis=0)
        wet += shifted[:, ::-1] * gain if i % 2 else shifted * gain
    return pcm + wet


def metrics(pcm):
    derivative = np.diff(np.concatenate([pcm[-1:], pcm], axis=0), axis=0)
    seam = float(np.max(np.abs(pcm[0] - pcm[-1])))
    rms = float(np.sqrt(np.mean(pcm ** 2)))
    return {"frames": len(pcm), "duration_seconds": len(pcm) / RATE, "sample_rate_hz": RATE,
            "channels": 2, "peak_dbfs": 20 * math.log10(max(float(np.max(np.abs(pcm))), 1e-12)),
            "rms_dbfs": 20 * math.log10(max(rms, 1e-12)), "seam_delta": seam,
            "max_adjacent_delta": float(np.max(np.abs(derivative))),
            "mono_rms_ratio": float(np.sqrt(np.mean(pcm.mean(axis=1) ** 2))) / max(rms, 1e-12)}


def write_wav(path, pcm):
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, pcm, RATE, subtype="PCM_24")


def export_loop(name, pcm, category, gain=1.0):
    pcm = pcm * gain
    assert np.isfinite(pcm).all() and np.max(np.abs(pcm)) < 0.85
    master = MASTERS / f"{name}.wav"
    write_wav(master, pcm)
    output = OUTPUT / f"{name}.ogg"
    subprocess.run([FFMPEG, "-nostdin", "-y", "-hide_banner", "-loglevel", "error", "-i", str(master),
                    "-c:a", "libvorbis", "-q:a", "5", "-ar", str(RATE), str(output)], check=True)
    decoded = OUTPUT.parent / f".{name}-decoded.wav"
    subprocess.run([FFMPEG, "-nostdin", "-y", "-hide_banner", "-loglevel", "error", "-i", str(output),
                    "-c:a", "pcm_f32le", str(decoded)], check=True)
    encoded_pcm, decoded_rate = sf.read(decoded, always_2d=True)
    decoded.unlink()
    assert decoded_rate == RATE and len(encoded_pcm) == len(pcm), "Encoder must retain exact musical frame count"
    result = metrics(encoded_pcm)
    assert result["mono_rms_ratio"] > 0.85
    assert result["seam_delta"] < max(0.008, result["max_adjacent_delta"] * 1.4), "Discontinuous encoded loop"
    result.update(file=output.name, role=category, loop=True, sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
                  master_sha256=hashlib.sha256(master.read_bytes()).hexdigest(), bytes=output.stat().st_size)
    print(f"EXPORT {output.name}: {result['peak_dbfs']:.1f} dBFS, {result['duration_seconds']:.6f}s", flush=True)
    return result


def ui_sounds():
    # Quiet tactile wood/piano signatures, related to the score without long jingles.
    definitions = {
        "ui_select": [("log", 60, 0.0, 0.18, 0.22), ("piano", 62, 0.01, 0.18, 0.10)],
        "ui_confirm": [("piano", 62, 0.0, 0.25, 0.16), ("piano", 69, 0.07, 0.27, 0.13)],
        "ui_back": [("piano", 65, 0.0, 0.17, 0.12), ("log", 60, 0.035, 0.14, 0.15)],
    }
    outputs = []
    for name, events in definitions.items():
        pcm = np.zeros((round(RATE * 0.65), 2))
        for index, (kind, pitch, start, duration, gain) in enumerate(events):
            sample = performed(kind, pitch, round(duration * RATE), index) * gain
            offset = round(start * RATE)
            count = min(len(sample), len(pcm) - offset)
            pcm[offset:offset + count] += sample[:count]
        pcm = pcm.mean(axis=1)
        peak_target = {"ui_focus": 0.12, "ui_select": 0.20, "ui_confirm": 0.18, "ui_back": 0.14}[name]
        pcm *= peak_target / max(float(np.max(np.abs(pcm))), 1e-9)
        pcm[-round(RATE * 0.06):] *= np.linspace(1, 0, round(RATE * 0.06)) ** 2
        output = OUTPUT / f"{name}.wav"
        sf.write(output, pcm, RATE, subtype="PCM_16")
        outputs.append({"file": output.name, "role": "interface", "loop": False,
                        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "bytes": output.stat().st_size,
                        "peak_dbfs": 20 * math.log10(max(float(np.max(np.abs(pcm))), 1e-12))})
    return outputs


def inspect_sources():
    for kind in ["piano", "cello", "viola", "violin", "flute", "horn", "harp"]:
        path = POOLS[kind][len(POOLS[kind]) // 2]
        pcm = recording(path).mean(axis=1)
        segment = pcm[int(RATE * 0.35):int(RATE * 1.35)]
        spectrum = np.abs(np.fft.rfft(segment * np.hanning(len(segment))))
        peaks = sorted(np.argpartition(spectrum, -6)[-6:], key=lambda i: -spectrum[i])
        frequencies = np.fft.rfftfreq(len(segment), 1 / RATE)
        print(kind, Path(path).name, "expected Hz", round(440 * 2 ** ((pitch_from_name(path) - 69) / 12), 1),
              "spectral peaks", [round(float(frequencies[i]), 1) for i in peaks], flush=True)
    print("TOOLS", sys.version.split()[0], "numpy", np.__version__, "scipy", scipy.__version__, "soundfile", sf.__version__)


def render():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    MASTERS.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    if (MASTERS / "provenance.json").exists():
        raise ValueError("Source render already exists. Preserve it and use a new revision directory.")
    outputs, packages = [], []
    for daylight in [False, True]:
        family = "horizon" if not daylight else "daybreak"
        score = compose(daylight)
        stems = [room(layer) * balance for layer, balance in zip(score.audio, [1.0, 0.85, 2.5, 1.7, 1.8])]
        full = sum(stems)
        # One common gain across ALL layers preserves their composed relative balance.
        gain = min(0.40 / max(float(np.max(np.abs(full))), 1e-9), 0.05 / max(float(np.sqrt(np.mean(full ** 2))), 1e-9))
        for index, (label, pcm) in enumerate(zip(LAYER_NAMES, stems)):
            outputs.append(export_loop(f"{family}_{label}", pcm, "additive_runtime_layer", gain))
        write_wav(EVIDENCE / f"{family}-full-v{REVISION}.wav", full * gain)
        # Offline illustrative driving development. Actual Godot captures are separate evidence.
        length = RATE * 90
        mix = np.zeros((length, 2))
        timeline = np.arange(length, dtype=np.float64) / RATE
        for index, pcm in enumerate(stems):
            looped = np.tile(pcm, (2, 1))[:length]
            threshold = [0, 12, 24, 40, 56][index]
            weight = np.clip((timeline - threshold) / 4, 0, 1)
            if index == 0: weight[:] = 1
            weight = weight * weight * (3 - 2 * weight)
            mix += looped * (weight * gain)[:, None]
        mix[:int(RATE * .6)] *= np.linspace(0, 1, int(RATE * .6))[:, None]
        mix[-RATE:] *= np.linspace(1, 0, RATE)[:, None]
        write_wav(EVIDENCE / f"{family}-clean-race-v{REVISION}.wav", mix)
        packages.append({"id": family, "name": ("Rolling Start" if not daylight else "Sunlit Sprint") if UPBEAT else ("Open Horizon" if not daylight else "First Light"),
                         "bpm": BPM, "bars": BARS, "frames": FRAMES, "layers": [f"{family}_{n}.ogg" for n in LAYER_NAMES],
                         "score": score.events, "combined": metrics(full * gain), "common_gain": gain})
    menu = compose(False, menu=True)
    menu_pcm = room(menu.audio[0])
    menu_gain = min(0.28 / max(float(np.max(np.abs(menu_pcm))), 1e-9), 0.05 / max(float(np.sqrt(np.mean(menu_pcm ** 2))), 1e-9))
    outputs.append(export_loop("menu_workshop", menu_pcm, "complete_menu_mix", menu_gain))
    write_wav(EVIDENCE / f"menu-workshop-v{REVISION}.wav", menu_pcm * menu_gain)
    outputs += ui_sounds()
    source_summary = [{"path_or_uri": item["url"], "sha256": item["sha256"], "license_or_terms": item["license"]}
                      for item in SOURCE_MANIFEST["sources"]]
    manifest = {"schema_version": 1, "asset_id": f"bmt-original-chamber-score-v1-mix{REVISION}", "revision": REVISION, "direction": "upbeat_racing" if UPBEAT else "chamber_original", "status": "integrated_for_owner_audition",
                "created_at": datetime.now(timezone.utc).isoformat(), "source_type": "rendered",
                "generator": {"tool": "original-written-score/sample-renderer", "tool_version": 1,
                              "model": None, "backend": "offline-numpy-scipy", "device": "CPU",
                              "command_or_entrypoint": "tools/music_generator/scripts/render_score_v1.sh",
                              "python": sys.version.split()[0], "numpy": np.__version__, "scipy": scipy.__version__, "soundfile": sf.__version__},
                "generation": {"prompt_or_config": "render_score_v1.py: UPBEAT_CHORDS, UPBEAT_MELODY, compose_upbeat" if UPBEAT else "render_score_v1.py: CHORDS, MELODY, compose", "seed": None,
                               "parameters": {"sample_rate": RATE, "race_bpm": BPM, "race_bars": BARS, "menu_bpm": MENU_BPM}, "conditioning_sources": [],
                               "score_source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
                "input_sources": source_summary, "outputs": outputs, "packages": packages,
                "licensing": {"model_license": "No model", "output_terms_reviewed": True,
                              "external_source_licenses": ["VSCO 2 Community Edition CC0-1.0"], "commercial_use_status": "cleared source recordings; original score"},
                "approval": {"user_approved": False, "scope": [], "date": None},
                "modifications": ["original score", "bandlimited pitch resampling", "phrase expression", "circular note/reverb tails", "common family gain", "Vorbis q5 export"]}
    encoded = json.dumps(manifest, indent=2) + "\n"
    (MASTERS / "provenance.json").write_text(encoded)
    (OUTPUT / "manifest.json").write_text(encoded)
    (OUTPUT / "NOTICE.txt").write_text("Beat my track original chamber score v1 (2026-10-07)\n"
        "Original score and offline arrangement authored for this project. No reference-game audio or melodies used.\n"
        "Instrument recordings: VSCO 2 Community Edition, CC0-1.0. Recorded by Sam Gossner & Simon Dalzell; "
        "sample cutting by Elan Hickler/Soundemote. https://github.com/sgossner/VSCO-2-CE\n"
        "Pinned source revision: " + SOURCE_MANIFEST["revision"] + "\n"
        "Sources and full licence retained in build/music/score-v1/sources; hashes and export provenance in manifest.json.\n"
        "Artistic approval and phone listening remain pending.\n", encoding="utf-8")
    shutil.copyfile(SOURCE / "LICENSE", OUTPUT / "VSCO-LICENSE.txt")
    print("RENDER COMPLETE", len(outputs), "assets", sum(x["bytes"] for x in outputs), "shipping bytes", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--inspect", action="store_true")
    parser.add_argument("--revision", type=int, default=2)
    parser.add_argument("--upbeat", action="store_true")
    parser.add_argument("--evidence-dir", type=Path)
    args = parser.parse_args()
    if args.revision < 2: raise ValueError("Preserve initial masters. Use revision 2 or newer.")
    REVISION = args.revision
    UPBEAT = args.upbeat
    MENU_BPM = 108 if UPBEAT else 90
    if args.evidence_dir:
        EVIDENCE = (ROOT / args.evidence_dir).resolve()
        if not EVIDENCE.is_relative_to((ROOT / "docs/evidence").resolve()): raise ValueError("Evidence must stay under docs/evidence")
    MASTERS = ROOT / f"build/music/score-v1/masters-v{REVISION}"
    OUTPUT = ROOT / f"build/music/score-v1/exports-v{REVISION}"
    inspect_sources() if args.inspect else render()
