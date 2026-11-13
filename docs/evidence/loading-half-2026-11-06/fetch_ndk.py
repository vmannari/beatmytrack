"""User-authorized pinned NDK download/extraction into this task's build folder."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import time
import urllib.request
import zipfile

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
owned = root / 'build/loading-half-20261106'
source = json.loads((evidence / 'engine/ndk-source.json').read_text())
assert source['revision'] == '29.0.14206865'
assert source['archive_url'] == 'https://dl.google.com/android/repository/android-ndk-r29-windows.zip'
assert source['checksum_type'] == 'sha1'
archive = owned / 'android-ndk-r29-windows.zip'
destination = owned / 'android-sdk/ndk' / source['revision']
assert destination.resolve().is_relative_to(owned.resolve())
started = time.monotonic()
if not archive.exists():
    partial = archive.with_suffix('.zip.partial')
    with urllib.request.urlopen(source['archive_url'], timeout=45) as response, partial.open('xb') as output:
        count = 0
        digest = hashlib.sha1()
        while chunk := response.read(1024*1024):
            count += len(chunk)
            if count > source['bytes']:
                raise ValueError('Archive exceeds official manifest size')
            digest.update(chunk)
            output.write(chunk)
    if count != source['bytes'] or digest.hexdigest() != source['checksum']:
        raise ValueError('Official archive size/checksum mismatch')
    partial.replace(archive)
sha1, sha256 = hashlib.sha1(), hashlib.sha256()
with archive.open('rb') as stream:
    while chunk := stream.read(1024*1024):
        sha1.update(chunk)
        sha256.update(chunk)
assert archive.stat().st_size == source['bytes'] and sha1.hexdigest() == source['checksum']
print('Official NDK archive verified; extracting into owned build folder.', flush=True)
destination.mkdir(parents=True, exist_ok=False)
files = 0
with zipfile.ZipFile(archive) as package:
    for member in package.infolist():
        path = PurePosixPath(member.filename)
        if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0] != 'android-ndk-r29':
            raise ValueError('Unexpected archive path: ' + member.filename)
        target = destination.joinpath(*path.parts[1:])
        if not target.resolve().is_relative_to(destination.resolve()):
            raise ValueError('Archive path escaped destination')
        if member.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            with package.open(member) as stream, target.open('xb') as output:
                shutil.copyfileobj(stream, output, 1024*1024)
            files += 1
assert 'Pkg.Revision = 29.0.14206865' in (destination/'source.properties').read_text()
assert (destination/'toolchains/llvm/prebuilt/windows-x86_64/bin/clang++.exe').is_file()
receipt = dict(source, archive_sha256=sha256.hexdigest(), destination=str(destination),
               extracted_files=files, elapsed_seconds=time.monotonic()-started)
(evidence/'engine/ndk-download.json').write_text(json.dumps(receipt, indent=2)+'\n')
print(json.dumps(receipt), flush=True)
