"""Fetch three public CC0 previews into non-exported source storage; no login/API."""
from pathlib import Path
import hashlib
import json
import urllib.request
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "build/vehicle_audio_sources"
SOURCES = [
    ("collision_cc0", "qubodup", "https://freesound.org/people/qubodup/sounds/332058/", "https://cdn.freesound.org/previews/332/332058_71257-hq.mp3"),
    ("gravel_drive_cc0", "cognito perceptu", "https://freesound.org/people/cognito%20perceptu/sounds/97605/", "https://cdn.freesound.org/previews/97/97605_57789-hq.mp3"),
    ("stone_metal_cc0", "KALeigh0218", "https://freesound.org/people/KALeigh0218/sounds/655924/", "https://cdn.freesound.org/previews/655/655924_13723562-hq.mp3"),
]
records = []
for name, author, page, media in SOURCES:
    if "--finalize" in sys.argv:
        decoded = DEST / (name + ".f32")
        meta = json.loads((DEST / (name + ".decode.json")).read_text())
        pcm = decoded.read_bytes()
        rate = int(meta["rate"])
        fmt = struct.pack("<HHIIHH", 3, 1, rate, rate*4, 4, 32)
        data = b"WAVEfmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(pcm)) + pcm
        target = DEST / (name + ".wav")
        target.write_bytes(b"RIFF" + struct.pack("<I", len(data)) + data)
        records.append(dict(filename=target.name, author=author, source=page,
                            download=media, license="CC0-1.0", quality="public HQ MP3 preview decoded by pinned Godot",
                            encoded_sha256=hashlib.sha256((DEST / (name + ".mp3")).read_bytes()).hexdigest(),
                            sha256=hashlib.sha256(target.read_bytes()).hexdigest(), decoder="4.7.2.stable.official.ed1daf0bf", rate=rate))
        print(name, "decoded", len(pcm)//4, "frames")
        continue
    html = urllib.request.urlopen(page, timeout=30).read().decode()
    if "creativecommons.org/publicdomain/zero/1.0" not in html:
        raise ValueError("CC0 license missing: " + page)
    (DEST / (name + "-license.html")).write_text(html, encoding="utf-8")
    target = DEST / (name + ".mp3")
    if not target.exists():
        target.write_bytes(urllib.request.urlopen(media, timeout=30).read())
    records.append(dict(filename=target.name, author=author, source=page,
                        download=media, license="CC0-1.0", quality="public HQ MP3 preview",
                        sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    print(name, target.stat().st_size)
(DEST / "surface_source_manifest.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
