"""Offline preparation of recorded FWS rattles; never a runtime network dependency."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import urllib.request
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "game/assets/audio/ambience"
SOURCE = ROOT / "build/desert_rattlesnake/sources"
PAGE = "https://commons.wikimedia.org/wiki/File:Rattlesnake.ogg"
MEDIA = "https://upload.wikimedia.org/wikipedia/commons/2/22/Rattlesnake.ogg"
SOURCE_SHA256 = "145f92830ee8219e08d30d88f84966d5d5a5b94cdbbe1ebb9defa70bd79e6755"
RATE = 44100


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "BeatMyTrackAssetPrep/1.0"}), timeout=30).read()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--decode", action="store_true")
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    if args.fetch:
        html = fetch(PAGE)
        if b"PD-USGov-FWS" not in html:
            raise ValueError("Expected recording-specific public-domain metadata missing")
        (SOURCE / "license.html").write_bytes(html)
        (SOURCE / "rattlesnake.ogg").write_bytes(fetch(MEDIA))
    source_hash = hashlib.sha256((SOURCE / "rattlesnake.ogg").read_bytes()).hexdigest()
    if SOURCE_SHA256 and source_hash != SOURCE_SHA256:
        raise ValueError("Rattlesnake source changed; review provenance before rebuilding")
    if args.decode:
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "scripts/dev.ps1"),
                        "-Action", "TestScript", "-ScriptPath", "res://tests/decode_rattlesnake_source.gd"], cwd=ROOT, check=True)
    meta = json.loads((SOURCE / "rattlesnake.decode.json").read_text())
    raw = (SOURCE / "rattlesnake.f32").read_bytes()
    if hashlib.sha256(raw).hexdigest() != meta["sha256"]: raise ValueError("Decoded source checksum mismatch")
    values = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    if meta["rate"] != RATE:
        positions = np.arange(round(len(values) * RATE / meta["rate"]), dtype=np.float64) * meta["rate"] / RATE
        values = np.interp(positions, np.arange(len(values), dtype=np.float64), values)
    clips = []
    for filename, start, seconds in [("desert_rattle_a.wav", 1.5, 3.0), ("desert_rattle_b.wav", 7.0, 3.8)]:
        clip = values[round(start * RATE):round((start + seconds) * RATE)].copy()
        clip -= clip.mean()
        edge = round(0.05 * RATE)
        fade = np.sin(np.linspace(0, np.pi / 2, edge)) ** 2
        clip[:edge] *= fade
        clip[-edge:] *= fade[::-1]
        clip *= min(10 ** (-21 / 20) / np.sqrt(np.mean(clip ** 2)), 10 ** (-6 / 20) / np.max(np.abs(clip)))
        pcm = np.round(clip * 32767).astype("<i2")
        path = BANK / filename
        with wave.open(str(path), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm.tobytes())
        clips.append(dict(filename=filename, source_start_seconds=start, seconds=seconds, rate=RATE, channels=1,
                          bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                          rms_dbfs=float(20 * np.log10(np.sqrt(np.mean(clip ** 2)))),
                          peak_dbfs=float(20 * np.log10(np.max(np.abs(clip))))))
    manifest = dict(author="U.S. Fish and Wildlife Service; Ogg conversion uploaded by Borisblue to Wikimedia Commons",
                    license="PD-USGov-FWS (recording-specific public-domain tag on source page)",
                    source=PAGE, download=MEDIA, source_sha256=source_hash, decoded_sha256=meta["sha256"],
                    edits="Two recorded excerpts, original tone/pitch; mono44.1kHz16-bit PCM, DC removal, 50ms edge fades and level matching. No synthesis or extra rattles.",
                    clips=clips, total_bytes=sum(item["bytes"] for item in clips))
    (BANK / "desert_rattlesnake_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__": main()
