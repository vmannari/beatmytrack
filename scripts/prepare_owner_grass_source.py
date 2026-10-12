"""Register the owner's two MP3 rustle clips and their pinned-engine float decodes."""
from pathlib import Path
import hashlib
import json
import struct

dest = Path(__file__).resolve().parents[1] / 'build/vehicle_audio_sources'
records = []
for identity,original in [('511299','dragon-studio-grass-rustling-05-511299.mp3'),
                          ('511301','dragon-studio-grass-rustling-04-511301.mp3')]:
    stem = 'owner_grass_'+identity
    meta = json.loads((dest / (stem+'.decode.json')).read_text())
    pcm = (dest / (stem+'.f32')).read_bytes()
    assert len(pcm)==int(meta['frames'])*4
    rate = int(meta['rate'])
    fmt = struct.pack('<HHIIHH',3,1,rate,rate*4,4,32)
    body = b'WAVEfmt '+struct.pack('<I',len(fmt))+fmt+b'data'+struct.pack('<I',len(pcm))+pcm
    target = dest / (stem+'.wav')
    target.write_bytes(b'RIFF'+struct.pack('<I',len(body))+body)
    records.append(dict(filename=target.name,original_filename=original,
        author='Dragon Studio (owner filename; attribution not independently verified)',
        source='owner-supplied local MP3 selected on 2026-10-11',
        license='owner-authorized local use; third-party license not supplied',
        quality='owner-supplied MP3 decoded locally by pinned Godot',
        encoded_sha256=hashlib.sha256((dest / (stem+'.mp3')).read_bytes()).hexdigest(),
        sha256=hashlib.sha256(target.read_bytes()).hexdigest(),decoder=meta['decoder'],rate=rate))
(dest / 'owner_grass_source_manifest.json').write_text(json.dumps(records,indent=2)+'\n')
print('OWNER_GRASS_SOURCES:',len(records),'registered')
