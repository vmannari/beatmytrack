"""Fetch/register the owner's selected CC0 rally-car rail-scrape preview."""
from pathlib import Path
import hashlib
import json
import re
import struct
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "build/vehicle_audio_sources"
URL = "https://freesound.org/people/P%C3%B3l/sounds/385939/"
stem = "rail_scrape_pol_cc0"
if "--finalize" not in sys.argv:
    license_file = DEST / (stem+"-license.html")
    html = license_file.read_text(encoding="utf-8-sig") if license_file.exists() else urllib.request.urlopen(URL,timeout=30).read().decode()
    assert "creativecommons.org/publicdomain/zero/1.0" in html, "CC0 license must be present"
    (DEST / (stem+"-license.html")).write_text(html,encoding="utf-8")
    urls = sorted(set(re.findall(r'https://[^\s"<>]+\.mp3',html)))
    preview = next(url for url in urls if url.startswith("https://cdn.freesound.org/previews/385/385939_") and url.endswith("-hq.mp3"))
    media_file = DEST / (stem+".mp3")
    data = media_file.read_bytes() if media_file.exists() else urllib.request.urlopen(preview,timeout=30).read()
    (DEST / (stem+".mp3")).write_bytes(data)
    (DEST / (stem+".source.json")).write_text(json.dumps({"source":URL,"download":preview},indent=2)+"\n")
    print("CONTINUOUS_SCRAPE_FETCH:",len(data),"bytes; CC0 page saved;",preview)
else:
    meta = json.loads((DEST / (stem+".decode.json")).read_text())
    pcm = (DEST / (stem+".f32")).read_bytes()
    rate = int(meta["rate"])
    fmt = struct.pack("<HHIIHH",3,1,rate,rate*4,4,32)
    body = b"WAVEfmt "+struct.pack("<I",len(fmt))+fmt+b"data"+struct.pack("<I",len(pcm))+pcm
    target = DEST / (stem+".wav")
    target.write_bytes(b"RIFF"+struct.pack("<I",len(body))+body)
    origin = json.loads((DEST / (stem+".source.json")).read_text())
    record = {"filename":target.name,"author":"Pól","title":"S023_Metal_Rail_Scrape_Mono.wav",
              **origin,"license":"CC0-1.0","quality":"public HQ MP3 preview decoded by pinned Godot",
              "encoded_sha256":hashlib.sha256((DEST / (stem+".mp3")).read_bytes()).hexdigest(),
              "sha256":hashlib.sha256(target.read_bytes()).hexdigest(),"decoder":meta["decoder"],"rate":rate}
    (DEST / "continuous_scrape_source_manifest.json").write_text(json.dumps([record],indent=2)+"\n")
    print("CONTINUOUS_SCRAPE_SOURCE:",len(pcm)//4,"frames at",rate)
