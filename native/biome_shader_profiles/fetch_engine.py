"""Fetch the pinned official engine into an owned build directory."""
from pathlib import Path
import hashlib, json, tarfile, urllib.request
root = Path(__file__).resolve().parents[2]
dest = root/'build/biome-shader-profiles-20261106'
dest.mkdir(parents=True, exist_ok=True)
archive = dest/'godot-4.7.2-stable.tar.gz'
url = 'https://codeload.github.com/godotengine/godot/tar.gz/refs/tags/4.7.2-stable'
if not archive.exists():
    with urllib.request.urlopen(url, timeout=120) as source, archive.open('wb') as target:
        while chunk := source.read(1024*1024): target.write(chunk)
with tarfile.open(archive) as bundle:
    for member in bundle.getmembers():
        if not (dest/member.name).resolve().is_relative_to(dest.resolve()) or member.issym() or member.islnk():
            raise ValueError('Unexpected archive path/link')
    bundle.extractall(dest)
receipt = {'url':url, 'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(), 'bytes':archive.stat().st_size}
(root/'docs/evidence/biome-shader-profiles-2026-11-06/engine-source.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(receipt)
