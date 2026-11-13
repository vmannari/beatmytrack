"""Read native PNGs with stdlib only; compare failed pixels to original-repeat control."""
import json
import struct
import zlib
from pathlib import Path
E = Path(__file__).resolve().parent


def decode(path):
    data = path.read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n'
    pos,parts = 8,[]
    while pos<len(data):
        size = struct.unpack('>I',data[pos:pos+4])[0]
        kind,body = data[pos+4:pos+8],data[pos+8:pos+8+size]
        if kind==b'IHDR': width,height,bits,colour,compression,filtering,interlace=struct.unpack('>IIBBBBB',body)
        if kind==b'IDAT': parts.append(body)
        pos += size+12
    assert bits==8 and colour in (2,6) and compression==filtering==interlace==0
    channels = 4 if colour==6 else 3
    stride = width*channels
    raw = zlib.decompress(b''.join(parts))
    result = bytearray()
    previous = bytearray(stride)
    for y in range(height):
        mode = raw[y*(stride+1)]
        row = bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
        for x in range(stride):
            a = row[x-channels] if x>=channels else 0
            b = previous[x]
            c = previous[x-channels] if x>=channels else 0
            if mode==1: predictor=a
            elif mode==2: predictor=b
            elif mode==3: predictor=(a+b)//2
            elif mode==4:
                p=a+b-c
                distances=(abs(p-a),abs(p-b),abs(p-c))
                predictor=(a,b,c)[distances.index(min(distances))]
            else:
                assert mode==0
                predictor=0
            row[x]=(row[x]+predictor)&255
        result.extend(row)
        previous=row
    return width,height,channels,result


folder=E/'cars/fitted-compatibility-controls'
before=decode(folder/'compact-fitted-before.png')
after=decode(folder/'compact-fitted-after.png')
control=decode(folder/'compact-fitted-procedural-control.png')
assert before[:3]==after[:3]==control[:3]
w,h,c,_=before
def differences(other):
    return {str((i//c%w,i//c//w)):{'before':list(before[3][i:i+c]),'after':list(other[3][i:i+c])}
        for i in range(0,len(before[3]),c) if before[3][i:i+c]!=other[3][i:i+c]}
cached,original=differences(after),differences(control)
receipt={'cached':cached,'procedural_original_repeat':original,
    'cached_changes_exact_subset_of_original_repeat':all(original.get(k)==v for k,v in cached.items()),
    'strict_frame_assertion_retained_as_failed':True}
(E/'pixel-control.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))
