"""Read-only byte comparison of Godot RGBA8 PNG captures, using stdlib only."""
import json
from pathlib import Path
import struct
import sys
import zlib

def rgba(path):
    content = path.read_bytes()
    assert content[:8] == b'\x89PNG\r\n\x1a\n'
    cursor, compressed = 8, bytearray()
    width = height = 0
    while cursor < len(content):
        length = struct.unpack('>I',content[cursor:cursor+4])[0]
        tag, data = content[cursor+4:cursor+8], content[cursor+8:cursor+8+length]
        if tag == b'IHDR':
            width,height,depth,kind,compression,filtering,interlace = struct.unpack('>IIBBBBB',data)
            assert (depth,kind,compression,filtering,interlace)==(8,6,0,0,0)
        if tag == b'IDAT': compressed.extend(data)
        cursor += length+12
    raw = zlib.decompress(compressed)
    stride = width*4
    previous, result, offset = bytearray(stride), bytearray(), 0
    for _ in range(height):
        kind = raw[offset]
        row = bytearray(raw[offset+1:offset+1+stride])
        offset += stride+1
        for i in range(stride):
            a = row[i-4] if i>=4 else 0
            b = previous[i]
            c = previous[i-4] if i>=4 else 0
            if kind == 1: row[i] = (row[i]+a)&255
            elif kind == 2: row[i] = (row[i]+b)&255
            elif kind == 3: row[i] = (row[i]+(a+b)//2)&255
            elif kind == 4:
                p = a+b-c
                pa,pb,pc = abs(p-a),abs(p-b),abs(p-c)
                predictor = a if pa<=pb and pa<=pc else b if pb<=pc else c
                row[i] = (row[i]+predictor)&255
            else: assert kind == 0
        result.extend(row)
        previous = row
    return width,height,result

reference = Path(sys.argv[1])
width,height,expected = rgba(reference)
rows = []
for name in sys.argv[2:]:
    path = Path(name)
    w,h,actual = rgba(path)
    assert (w,h)==(width,height)
    count = maximum = total = 0
    left,top,right,bottom = width,height,-1,-1
    for index,(a,b) in enumerate(zip(expected,actual)):
        difference = abs(a-b)
        if difference:
            count += 1
            total += difference
            maximum = max(maximum,difference)
            x,y = (index//4)%width,(index//4)//width
            left,top,right,bottom = min(left,x),min(top,y),max(right,x),max(bottom,y)
    rows.append(dict(path=str(path),changed_channels=count,max_channel_difference=maximum,
                     total_difference=total,bounds=[left,top,right,bottom] if count else None))
print(json.dumps(rows,indent=2))
