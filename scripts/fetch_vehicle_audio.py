"""Fetch free CC0 audio sources into export-excluded build storage."""
from pathlib import Path
import http.cookiejar
import json
import re
import urllib.parse
import urllib.request
import io
import zipfile
import hashlib

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "build" / "vehicle_audio_sources"
DEST.mkdir(parents=True, exist_ok=True)
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
opener.addheaders = [("User-Agent", "Mozilla/5.0")]
page = "https://nox-sound-design.itch.io/essentials-series-sfx-nox-sound"
html = opener.open(page, timeout=30).read().decode()
csrf = re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)
payload = urllib.parse.urlencode({"csrf_token": csrf}).encode()
response = json.loads(opener.open(page + "/download_url", payload, timeout=30).read())
download = opener.open(response["url"], timeout=30).read().decode()
csrf = re.search(r'name="csrf_token" value="([^"]+)"', download).group(1)
file_url = page + "/file/17838594?source=game_download"
file_response = json.loads(opener.open(file_url, urllib.parse.urlencode({"csrf_token":csrf}).encode(), timeout=30).read())
if "url" not in file_response:
    raise RuntimeError(file_response)
url = file_response["url"]

class RemoteZip(io.RawIOBase):
    def __init__(self):
        probe = opener.open(urllib.request.Request(url, headers={"Range":"bytes=0-0"}), timeout=30)
        self.size = int(probe.headers["Content-Range"].split("/")[-1])
        self.position = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.size + offset
        return self.position
    def read(self, count=-1):
        count = self.size - self.position if count < 0 else min(count, self.size - self.position)
        if count <= 0: return b""
        request = urllib.request.Request(url, headers={"Range":f"bytes={self.position}-{self.position+count-1}"})
        with opener.open(request, timeout=60) as result:
            if result.status != 206: raise RuntimeError("Library server does not support bounded range downloads")
            data = result.read()
        self.position += len(data)
        return data

with zipfile.ZipFile(RemoteZip()) as archive:
    names = archive.namelist()
    (DEST / "library_index.json").write_text(json.dumps(names, indent=2), encoding="utf-8")
    selected = {
        "Vehicle_Car_Engine_1000_RPM_Front_Exterior_Loop_Mono.wav",
        "Vehicle_Car_Engine_1000_RPM_Rear_Exterior_Loop_Mono.wav",
        "Vehicle_Car_Engine_2000_RPM_Front_Exterior_Loop_Mono.wav",
        "Vehicle_Car_Engine_2000_RPM_Rear_Exterior_Loop_Mono.wav",
        "Vehicle_Car_Engine_Idle_Exterior_Loop_Mono_01.wav",
        "Vehicle_Car_Drive_Interior_Loop_Stereo_01.wav",
        "Vehicle_Truck_Idle_Exterior_Front_Loop_Stereo_01.wav",
        "Vehicle_Truck_Idle_Exterior_Rear_Loop_Stereo_01.wav",
        "Vehicle_Truck_Drive_Exterior_Loop_Stereo_01.wav",
        "Vehicle_Truck_Drive_Dirty_Ground_Exterior_Loop_Stereo.wav",
        "Vehicle_Truck_Drive_Grass_Exterior_Loop_Stereo.wav",
        "Vehicle_Car_Trunk_Close_Impact_Mono.wav",
        "Vehicle_Car_Door_Closing_Exterior_Mono_01.wav",
        "Vehicle_Car_Door_Closing_Exterior_Mono_02.wav",
        "Vehicle_Truck_Body_Movement_Interior_Mono_01.wav",
        "Footsteps_Iceland_Run_Black_Pebble_Mono_01.wav",
        "Footsteps_Iceland_Run_Black_Pebble_Mono_03.wav",
        "Footsteps_Iceland_Run_Black_Pebble_Mono_05.wav",
    }
    records = []
    for name in names:
        filename = Path(name).name
        if filename not in selected: continue
        target = DEST / filename
        if not target.exists(): target.write_bytes(archive.read(name))
        records.append({"filename":filename,"source":page,"archive_member":name,"license":"CC0-1.0","author":"Nox Sound Design","sha256":hashlib.sha256(target.read_bytes()).hexdigest()})
        print("Source ready:", filename, target.stat().st_size, flush=True)
    if {r["filename"] for r in records} != selected: raise RuntimeError("Missing selected library recordings")

for slug, number, author in [
    ("ac-cobra-engine-s0534.html", "0534", "Joseph SARDIN"),
    ("motorcycle-s0281.html", "0281", "DenisChardonnet"),
    ("motor-car-1-s0290.html", "0290", "DenisChardonnet"),
]:
    source_page = "https://bigsoundbank.com/" + slug
    source_html = opener.open(source_page, timeout=30).read().decode()
    if "CC0 (public domain)" not in source_html: raise RuntimeError("Source license changed: " + source_page)
    target = DEST / (number + ".wav")
    if not target.exists() or not target.read_bytes().startswith(b"RIFF"):
        target.write_bytes(opener.open("https://bigsoundbank.com/UPLOAD/bwf-en/" + number + ".wav",timeout=60).read())
        if not target.read_bytes().startswith(b"RIFF"): raise RuntimeError("WAV endpoint did not return audio")
    records.append({"filename":target.name,"source":source_page,"license":"CC0-1.0","author":author,"sha256":hashlib.sha256(target.read_bytes()).hexdigest()})
    print("Source ready:", target.name, target.stat().st_size, flush=True)

source_page = "https://opengameart.org/content/car-tire-squeal-skid-loop"
source_html = opener.open(source_page, timeout=30).read().decode()
matches = re.findall(r'href="([^"]*tires_squal_loop\.wav)"', source_html)
target = DEST / "tires_squal_loop.wav"
if not target.exists(): target.write_bytes(opener.open(matches[0],timeout=60).read())
records.append({"filename":target.name,"source":source_page,"license":"CC-BY-3.0","author":"audible-edge (Tom Haigh); loop edit by qubodup","sha256":hashlib.sha256(target.read_bytes()).hexdigest()})
(DEST / "source_manifest.json").write_text(json.dumps(records,indent=2)+"\n",encoding="utf-8")
print("Verified", len(records), "recordings", flush=True)
