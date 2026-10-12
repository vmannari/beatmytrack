"""Offline CC0 cicada loop mastering. NumPy is a build tool only."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import urllib.request
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/night_ambience_sources"
OUT = ROOT / "game/assets/audio/ambience"
PAGE = "https://bigsoundbank.com/cigales-s3002.html"
MEDIA = "https://bigsoundbank.com/UPLOAD/bwf-en/3002.wav"
RATE = 44100


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    master = SOURCE / "cicadas-3002.wav"
    if args.fetch:
        html = urllib.request.urlopen(PAGE, timeout=30).read()
        if b"CC0" not in html or b"Clarisse" not in html:
            raise ValueError("Expected CC0 author/license metadata missing")
        (SOURCE / "license.html").write_bytes(html)
        master.write_bytes(urllib.request.urlopen(MEDIA, timeout=30).read())
    data = master.read_bytes()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("Expected RIFF WAV source")
    cursor = 12
    raw = None
    while cursor + 8 <= len(data):
        kind, size = struct.unpack_from("<4sI", data, cursor)
        body = data[cursor + 8:cursor + 8 + size]
        if kind == b"fmt ":
            fmt, channels, rate, _, _, bits = struct.unpack_from("<HHIIHH", body)
            if fmt == 65534: fmt = struct.unpack_from("<H", body, 24)[0]
            if fmt != 1: raise ValueError("Expected PCM source")
            width = bits // 8
        elif kind == b"data":
            raw = body
        cursor += 8 + size + (size & 1)
    if raw is None: raise ValueError("WAV data chunk missing")
    if width == 3:
        data = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        values = data[:, 0] | data[:, 1] << 8 | data[:, 2] << 16
        values = ((values ^ 0x800000) - 0x800000) / 8388608.0
    elif width == 2:
        values = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    else:
        raise ValueError("Expected 16/24-bit PCM")
    values = values.reshape(-1, channels).mean(axis=1)
    # Use a stable middle section; retain a full extra second for the loop overlap.
    values = values[round(8 * rate):round(27 * rate)]
    if len(values) != 19 * rate:
        raise ValueError("Source is too short")
    positions = np.arange(round(len(values) * RATE / rate), dtype=np.float64) * (rate / RATE)
    values = np.interp(positions, np.arange(len(values), dtype=np.float64), values)
    hz = np.fft.rfftfreq(len(values), 1 / RATE)
    spectrum = np.fft.rfft(values)
    # Remove outdoor rumble and soften the highest insect frequencies.
    spectrum *= (1 - np.exp(-(hz / 450) ** 4)) * np.exp(-(hz / 8500) ** 4)
    values = np.fft.irfft(spectrum, n=len(values))
    overlap = RATE
    ramp = np.linspace(0, 1, overlap, endpoint=False)
    blend = values[-overlap:] * (1 - ramp) + values[:overlap] * ramp
    values = np.concatenate([values[overlap:-overlap], blend])
    values *= min(10 ** (-22 / 20) / np.sqrt(np.mean(values ** 2)), 10 ** (-6 / 20) / np.max(np.abs(values)))
    pcm = np.round(values * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / "night_cicadas.wav"
    with wave.open(str(target), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    manifest = dict(
        filename=target.name, author="Clarisse", title="Cicadas", license="CC0-1.0",
        source=PAGE, download=MEDIA, source_sha256=hashlib.sha256(master.read_bytes()).hexdigest(),
        sha256=hashlib.sha256(target.read_bytes()).hexdigest(), rate=RATE, channels=1,
        seconds=len(pcm) / RATE, bytes=target.stat().st_size,
        edits="8-27s field recording; mono; 44.1kHz; rumble/high-frequency softening; 1s cyclic crossfade; RMS -22dBFS with -6dBFS peak cap",
        peak_dbfs=float(20 * np.log10(np.max(np.abs(values)))),
        rms_dbfs=float(20 * np.log10(np.sqrt(np.mean(values ** 2)))),
        seam_step=float(abs(int(pcm[-1]) - int(pcm[0])) / 32768),
    )
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
