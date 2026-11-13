"""Fetch a checksum-verified official portable Blender into this workspace."""
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[3]
BASE = "https://download.blender.org/release/Blender4.5/"
VERSION = "4.5.15"
NAME = "blender-" + VERSION + "-windows-x64"
OUT = ROOT / "build/tools"
OUT.mkdir(parents=True, exist_ok=True)
archive = OUT / (NAME + ".zip")
checks = urllib.request.urlopen(BASE + "blender-" + VERSION + ".sha256", timeout=45).read().decode()
expected = next(line.split()[0] for line in checks.splitlines() if line.rstrip().endswith(archive.name))
if not archive.exists():
    with urllib.request.urlopen(BASE + archive.name, timeout=90) as response, archive.open("wb") as target:
        while block := response.read(4 * 1024 * 1024):
            target.write(block)
actual = hashlib.file_digest(archive.open("rb"), "sha256").hexdigest() if hasattr(hashlib, "file_digest") else hashlib.sha256(archive.read_bytes()).hexdigest()
assert actual == expected, "Official archive checksum mismatch"
with zipfile.ZipFile(archive) as source:
    for entry in source.infolist():
        target = (OUT / entry.filename).resolve()
        assert target.is_relative_to(OUT.resolve()), "Archive escapes the tools directory"
    source.extractall(OUT)
(Path(__file__).parent / "blender-tool.json").write_text(json.dumps({"version": VERSION,
    "source": BASE + archive.name, "checksum_source": BASE + "blender-" + VERSION + ".sha256",
    "sha256": actual, "verified": actual == expected, "executable": str(OUT / NAME / "blender.exe")}, indent=2), encoding="utf-8")
print("BLENDER_READY:", OUT / NAME / "blender.exe", flush=True)
