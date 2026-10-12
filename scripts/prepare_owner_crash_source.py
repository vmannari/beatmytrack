"""Register the pinned-engine decode of the owner's selected crash recording."""
from pathlib import Path
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/vehicle_audio_sources"
stem = "owner_crash_394903"
meta = json.loads((SOURCE / (stem+".decode.json")).read_text())
pcm = (SOURCE / (stem+".f32")).read_bytes()
rate = int(meta["rate"])
assert len(pcm)==int(meta["frames"])*4
fmt = struct.pack("<HHIIHH",3,1,rate,rate*4,4,32)
body = b"WAVEfmt "+struct.pack("<I",len(fmt))+fmt+b"data"+struct.pack("<I",len(pcm))+pcm
target = SOURCE / (stem+".wav")
target.write_bytes(b"RIFF"+struct.pack("<I",len(body))+body)
record = {"filename":target.name,"original_filename":"u_mgq59j5ayf-sound-effect-car-crash-394903.mp3",
          "author":"not supplied","source":"owner-supplied local MP3 selected on 2026-10-10",
          "license":"owner-authorized local use; third-party license not supplied",
          "quality":"owner-supplied MP3 decoded locally by pinned Godot",
          "encoded_sha256":hashlib.sha256((SOURCE / (stem+".mp3")).read_bytes()).hexdigest(),
          "sha256":hashlib.sha256(target.read_bytes()).hexdigest(),"decoder":meta["decoder"],"rate":rate}
(SOURCE / "owner_crash_source_manifest.json").write_text(json.dumps([record],indent=2)+"\n")
print("OWNER_CRASH_SOURCE:",len(pcm)//4,"frames;",record["encoded_sha256"])
