"""Master three CC0 field-recorded bird phrases offline; no runtime services."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import urllib.request
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/grass_birds/sources"
OUT = ROOT / "game/assets/audio/ambience"
RATE = 44100
SOURCES = [
    (3486, "grass_blackbird_13", "Common Blackbird #13", "common-blackbird-13"),
    (3496, "grass_blackbird_23", "Common Blackbird #23", "common-blackbird-23"),
    (3472, "grass_blackcap_7", "Eurasian Blackcap #7", "eurasian-blackcap-7"),
]
SOURCE_HASHES = {
    3486: "40c4f85f8c3ad7d8f4a91a023784c308b656000e8cf016c7e23e2c55f9e2f0e8",
    3496: "512b75022890f88a209586635229e3e5eb4b3a16b495f6b5744b4de070c7adfa",
    3472: "9abe4cd9b8ce9892539983dcd9165976709e6e0d5b2257a25a740738a62a2195",
}


def decode_pcm(data):
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("Expected WAV source")
    cursor, raw, fmt_info = 12, None, None
    while cursor + 8 <= len(data):
        kind, size = struct.unpack_from("<4sI", data, cursor)
        body = data[cursor + 8:cursor + 8 + size]
        if kind == b"fmt ":
            fmt, channels, rate, _, _, bits = struct.unpack_from("<HHIIHH", body)
            if fmt == 65534:
                fmt = struct.unpack_from("<H", body, 24)[0]
            if fmt != 1 or bits not in [16, 24]:
                raise ValueError("Expected 16/24-bit PCM")
            fmt_info = (channels, rate, bits)
        elif kind == b"data":
            raw = body
        cursor += 8 + size + (size & 1)
    if raw is None or fmt_info is None:
        raise ValueError("Missing PCM chunks")
    channels, rate, bits = fmt_info
    if bits == 24:
        packed = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        values = packed[:, 0] | packed[:, 1] << 8 | packed[:, 2] << 16
        values = ((values ^ 0x800000) - 0x800000) / 8388608.0
    else:
        values = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    values = values.reshape(-1, channels).mean(axis=1)
    if not 1 < len(values) / rate < 12:
        raise ValueError("Expected short bird phrase")
    positions = np.arange(round(len(values) * RATE / rate)) * (rate / RATE)
    return np.interp(positions, np.arange(len(values)), values)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for number, filename, title, slug in SOURCES:
        page = f"https://bigsoundbank.com/{slug}-s{number}.html"
        media = f"https://bigsoundbank.com/UPLOAD/bwf-en/{number}.wav"
        master = SOURCE / f"{number}.wav"
        if args.fetch:
            html = urllib.request.urlopen(page, timeout=30).read()
            if b"CC0" not in html or b"Le tiroir du fond" not in html:
                raise ValueError(f"Expected CC0 author/license missing: {page}")
            (SOURCE / f"{number}-license.html").write_bytes(html)
            master.write_bytes(urllib.request.urlopen(media, timeout=30).read())
        source = master.read_bytes()
        if sha(source) != SOURCE_HASHES[number]:
            raise ValueError(f"Source changed; review provenance before rebuilding: {number}")
        values = decode_pcm(source)
        values -= values.mean()
        # Remove field rumble; retain natural call pitches and complete phrases.
        hz = np.fft.rfftfreq(len(values), 1 / RATE)
        spectrum = np.fft.rfft(values)
        spectrum *= (1 - np.exp(-(hz / 650) ** 4)) * np.exp(-(hz / 10500) ** 6)
        values = np.fft.irfft(spectrum, n=len(values))
        edge = round(0.06 * RATE)
        fade = np.sin(np.linspace(0, np.pi / 2, edge)) ** 2
        values[:edge] *= fade
        values[-edge:] *= fade[::-1]
        values *= min(10 ** (-23 / 20) / np.sqrt(np.mean(values ** 2)),
                      10 ** (-6 / 20) / np.max(np.abs(values)))
        pcm = np.round(values * 32767).astype("<i2")
        target = OUT / f"{filename}.wav"
        with wave.open(str(target), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm.tobytes())
        entries.append(dict(filename=target.name, title=title, author="Le tiroir du fond",
                            license="CC0-1.0", source=page, download=media,
                            source_sha256=sha(source), sha256=sha(target.read_bytes()),
                            seconds=len(pcm) / RATE, bytes=target.stat().st_size,
                            rate=RATE, channels=1,
                            peak_dbfs=float(20 * np.log10(np.max(np.abs(values)))),
                            rms_dbfs=float(20 * np.log10(np.sqrt(np.mean(values ** 2))))))
    manifest = dict(clips=entries, edits="Full phrases; mono 44.1kHz PCM; DC/rumble cleanup, gentle high-frequency softening, 60ms edge fades, RMS -23dBFS/peak cap -6dBFS; no loops or synthetic birds",
                    total_bytes=sum(entry["bytes"] for entry in entries))
    (OUT / "grass_birds_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
