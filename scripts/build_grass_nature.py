"""Offline mastering of a cleared leaf rustle. Existing cicada asset is reused unchanged."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import urllib.request
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/grass_nature/sources"
BANK = ROOT / "game/assets/audio/ambience"
PAGE = "https://opengameart.org/content/random-sounds-samples"
MEDIA = "https://opengameart.org/sites/default/files/moving%20leaves%20stereo.ogg"
SOURCE_SHA256 = "678c0da00ef1092f4be7c2d8c7b22c1c91c5fc8ca1f3f9570ce59de995c0138c"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    master = SOURCE / "moving_leaves.ogg"
    if args.fetch:
        html = urllib.request.urlopen(PAGE, timeout=30).read()
        if b"CC0" not in html or b"Brandon Morris" not in html:
            raise ValueError("Expected source author and CC0 licence metadata")
        (SOURCE / "license.html").write_bytes(html)
        master.write_bytes(urllib.request.urlopen(MEDIA, timeout=30).read())
    source_hash = sha(master.read_bytes())
    if SOURCE_SHA256 and source_hash != SOURCE_SHA256:
        raise ValueError("Leaf source changed; review provenance before rebuilding")
    subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                    str(ROOT / "scripts/dev.ps1"), "-Action", "TestScript", "-ScriptPath",
                    "res://tests/decode_grass_leaves.gd"], cwd=ROOT, check=True)
    decode = json.loads((SOURCE / "moving_leaves.decode.json").read_text())
    values = np.frombuffer((SOURCE / "moving_leaves.f32").read_bytes(), dtype="<f4").astype(np.float64)
    rate = 44100
    positions = np.arange(round(len(values) * rate / decode["rate"])) * decode["rate"] / rate
    values = np.interp(positions, np.arange(len(values)), values)
    values -= values.mean()
    hz = np.fft.rfftfreq(len(values), 1 / rate)
    spectrum = np.fft.rfft(values)
    spectrum *= (1 - np.exp(-(hz / 350) ** 4)) * np.exp(-(hz / 5500) ** 4)
    values = np.fft.irfft(spectrum, n=len(values))
    edge = round(0.08 * rate)
    fade = np.sin(np.linspace(0, np.pi / 2, edge)) ** 2
    values[:edge] *= fade
    values[-edge:] *= fade[::-1]
    values *= min(10 ** (-26 / 20) / np.sqrt(np.mean(values ** 2)),
                  10 ** (-8 / 20) / np.max(np.abs(values)))
    pcm = np.round(values * 32767).astype("<i2")
    target = BANK / "grass_leaves.wav"
    with wave.open(str(target), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(pcm.tobytes())
    insects = BANK / "night_cicadas.wav"
    manifest = dict(filename=target.name, title="Leaves rustling (moving leaves stereo.ogg)",
                    author="Augmentality (Brandon Morris), uploaded by HaelDB", license="CC0-1.0",
                    source=PAGE, download=MEDIA, source_sha256=source_hash,
                    decoded_sha256=decode["sha256"], sha256=sha(target.read_bytes()),
                    seconds=len(pcm) / rate, rate=rate, channels=1, bytes=target.stat().st_size,
                    rms_dbfs=float(20 * np.log10(np.sqrt(np.mean(values ** 2)))),
                    peak_dbfs=float(20 * np.log10(np.max(np.abs(values)))),
                    edits="Full recorded leaf-rustling foley; mono 44.1kHz PCM, DC/rumble removal, softened highs, 80ms edge fades, RMS -26dBFS/peak cap -8dBFS; runtime slow envelope and sparse gaps",
                    insects=dict(filename=insects.name, sha256=sha(insects.read_bytes()),
                                 author="Clarisse", source="https://bigsoundbank.com/cigales-s3002.html",
                                 license="CC0-1.0", edits="Reuse existing cleared 40s recording unchanged; quieter grass-only playback"))
    (BANK / "grass_nature_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
