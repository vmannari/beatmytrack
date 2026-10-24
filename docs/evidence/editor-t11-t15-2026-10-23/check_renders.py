"""Read-only exact PNG comparisons, using only Python's standard library."""
from pathlib import Path
import hashlib
import json
import struct
import zlib


def pixels(path):
    source = path.read_bytes()
    assert source[:8] == b'\x89PNG\r\n\x1a\n'
    offset, compressed = 8, bytearray()
    while offset < len(source):
        size = struct.unpack('>I', source[offset:offset+4])[0]
        kind, value = source[offset+4:offset+8], source[offset+8:offset+8+size]
        assert zlib.crc32(kind+value) == struct.unpack('>I',source[offset+8+size:offset+12+size])[0]
        if kind == b'IHDR':
            width,height,depth,color,compression,filtering,interlace = struct.unpack('>IIBBBBB',value)
            assert depth == 8 and color in (2,6) and interlace == 0
            channels = 4 if color == 6 else 3
        if kind == b'IDAT': compressed.extend(value)
        offset += size+12
    raw, stride = zlib.decompress(compressed), width*channels
    result, previous, offset = bytearray(), bytearray(stride), 0
    for _ in range(height):
        mode = raw[offset]
        row = bytearray(raw[offset+1:offset+1+stride]); offset += stride+1
        for i in range(stride):
            left, up = row[i-channels] if i >= channels else 0, previous[i]
            upper_left = previous[i-channels] if i >= channels else 0
            if mode == 1: predictor = left
            elif mode == 2: predictor = up
            elif mode == 3: predictor = (left+up)//2
            elif mode == 4:
                p = left+up-upper_left
                distances = abs(p-left),abs(p-up),abs(p-upper_left)
                predictor = (left,up,upper_left)[distances.index(min(distances))]
            else: assert mode == 0; predictor = 0
            row[i] = (row[i]+predictor)&255
        result.extend(row); previous = row
    return width,height,channels,result


root = Path(__file__).resolve().parent
rows = []
for original in sorted(root.rglob('*-original.png')):
    updated = original.with_name(original.name.replace('-original.png','-incremental.png'))
    if not updated.exists(): continue
    w,h,c,a = pixels(original); w2,h2,c2,b = pixels(updated)
    assert (w,h,c) == (w2,h2,c2)
    changed = [(i,x,y) for i,(x,y) in enumerate(zip(a,b)) if x != y]
    rows.append({'original':original.relative_to(root).as_posix(),
                 'sha256_original':hashlib.sha256(original.read_bytes()).hexdigest(),
                 'sha256_updated':hashlib.sha256(updated.read_bytes()).hexdigest(),
                 'width':w,'height':h,'changed_channels':len(changed),
                 'maximum':max((abs(x-y) for _,x,y in changed),default=0),
                 'first_differences':[{'x':(i//c)%w,'y':i//(c*w),'channel':i%c,'values':[x,y]} for i,x,y in changed[:16]]})
(root/'render-comparisons.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
for row in rows: print(row['original'],row['changed_channels'],row['maximum'],row['first_differences'][:3])
