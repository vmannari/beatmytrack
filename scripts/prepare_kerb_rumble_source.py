"""Register a locally downloaded public CC0 rumble-strip preview and Godot decode."""
from pathlib import Path
import hashlib
import json
import struct

dest = Path(__file__).resolve().parents[1] / 'build/vehicle_audio_sources'
stem = 'kerb_rumble_cc0'
page = (dest / (stem+'-license.html')).read_text(encoding='utf-8-sig')
assert 'creativecommons.org/publicdomain/zero/1.0' in page, 'CC0 license required'
meta = json.loads((dest / (stem+'.decode.json')).read_text())
pcm = (dest / (stem+'.f32')).read_bytes()
rate = int(meta['rate'])
fmt = struct.pack('<HHIIHH',3,1,rate,rate*4,4,32)
body = b'WAVEfmt '+struct.pack('<I',len(fmt))+fmt+b'data'+struct.pack('<I',len(pcm))+pcm
target = dest / (stem+'.wav')
target.write_bytes(b'RIFF'+struct.pack('<I',len(body))+body)
record = dict(filename=target.name, author='sengjinn', title='TRANSPORTATION CAR PASS BY 01.wav',
    source='https://freesound.org/people/sengjinn/sounds/176215/',
    download='https://cdn.freesound.org/previews/176/176215_2979997-hq.mp3',
    license='CC0-1.0', quality='public HQ MP3 preview decoded by pinned Godot',
    encoded_sha256=hashlib.sha256((dest / (stem+'.mp3')).read_bytes()).hexdigest(),
    sha256=hashlib.sha256(target.read_bytes()).hexdigest(), decoder=meta['decoder'], rate=rate)
(dest / 'kerb_source_manifest.json').write_text(json.dumps([record],indent=2)+'\n')
print('KERB_SOURCE:',len(pcm)//4,'frames at',rate)
