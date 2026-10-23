"""Fetch only four CC0 snow recordings from the existing Nox library."""
import hashlib
import http.cookiejar
import io
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "build/vehicle_audio_sources/snow"
PAGE = "https://nox-sound-design.itch.io/essentials-series-sfx-nox-sound"
NAMES = ["Footsteps_Snow_Run_01.wav", "Footsteps_Snow_Run_03.wav",
         "Footsteps_Snow_Hard_Run_02.wav", "Footsteps_Snow_Jump_Land_01.wav"]


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    opener.addheaders = [("User-Agent", "Mozilla/5.0")]
    page = opener.open(PAGE, timeout=30).read().decode()
    if "CC0" not in page:
        raise ValueError("Source page no longer identifies the library as CC0")
    (DEST / "license.html").write_text(page, encoding="utf-8")
    token = re.search(r'name="csrf_token" value="([^"]+)"', page).group(1)
    response = json.loads(opener.open(PAGE + "/download_url", urllib.parse.urlencode({"csrf_token": token}).encode(), timeout=30).read())
    download = opener.open(response["url"], timeout=30).read().decode()
    token = re.search(r'name="csrf_token" value="([^"]+)"', download).group(1)
    response = json.loads(opener.open(PAGE + "/file/17838594?source=game_download", urllib.parse.urlencode({"csrf_token": token}).encode(), timeout=30).read())
    url = response["url"]

    class RemoteZip(io.RawIOBase):
        def __init__(self):
            with opener.open(urllib.request.Request(url, headers={"Range": "bytes=0-0"}), timeout=30) as probe:
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
            with opener.open(urllib.request.Request(url, headers={"Range": f"bytes={self.position}-{self.position + count - 1}"}), timeout=60) as result:
                if result.status != 206: raise ValueError("Expected bounded range response")
                data = result.read()
            self.position += len(data)
            return data

    records = []
    with zipfile.ZipFile(RemoteZip()) as archive:
        for name in NAMES:
            member = next(item for item in archive.namelist() if Path(item).name == name)
            target = DEST / name
            if not target.exists(): target.write_bytes(archive.read(member))
            records.append({"filename": name, "source": PAGE, "archive_member": member,
                            "author": "Nox Sound Design", "license": "CC0-1.0",
                            "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
            print("Snow source ready:", name, target.stat().st_size, flush=True)
    (DEST / "manifest.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__": main()
