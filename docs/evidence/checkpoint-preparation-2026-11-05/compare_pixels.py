"""Dependency-free decoding/comparison of Godot's 8-bit RGB/RGBA captures."""
import json
from pathlib import Path
import struct
import zlib

def pixels(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    offset, compressed = 8, bytearray()
    while offset < len(data):
        size = struct.unpack('>I',data[offset:offset+4])[0]
        kind = data[offset+4:offset+8]
        value = data[offset+8:offset+8+size]
        if kind == b'IHDR': width,height,depth,color,compression,filtering,interlace = struct.unpack('>IIBBBBB',value)
        if kind == b'IDAT': compressed.extend(value)
        offset += size+12
    assert depth==8 and color in (2,6) and interlace==0
    channels = 3 if color==2 else 4
    stride = width*channels
    raw = zlib.decompress(compressed)
    result = bytearray()
    previous = bytearray(stride)
    for y in range(height):
        method = raw[y*(stride+1)]
        row = bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
        for x in range(stride):
            a = row[x-channels] if x>=channels else 0
            b = previous[x]
            c = previous[x-channels] if x>=channels else 0
            if method==1: predictor=a
            elif method==2: predictor=b
            elif method==3: predictor=(a+b)//2
            elif method==4:
                p=a+b-c; pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
                predictor=a if pa<=pb and pa<=pc else b if pb<=pc else c
            else: assert method==0; predictor=0
            row[x]=(row[x]+predictor)&255
        result.extend(row); previous=row
    return width,height,channels,result

evidence = Path(__file__).resolve().parent
game = Path(json.loads((evidence/'frozen-project.json').read_text())['project'])
rows=[]
for group in ('checkpoint-preparation-output','checkpoint-preparation-control','checkpoint-preparation-settled'):
    for renderer in ('gl_compatibility','mobile'):
        folder=game.parent/'build'/group/renderer
        if not (folder/'after-hairpin.png').exists(): continue
        width,height,channels,a=pixels(folder/'before-hairpin.png')
        w,h,c,b=pixels(folder/'after-hairpin.png')
        assert (w,h,c)==(width,height,channels)
        count,maximum,total=0,0,0
        bounds=[width,height,-1,-1]
        for i in range(0,len(a),channels):
            delta=[abs(a[i+j]-b[i+j]) for j in range(channels)]
            value=max(delta); total+=sum(delta)
            if value:
                count+=1; maximum=max(maximum,value)
                x,y=(i//channels)%width,(i//channels)//width
                bounds=[min(bounds[0],x),min(bounds[1],y),max(bounds[2],x),max(bounds[3],y)]
        rows.append(dict(group=group,renderer=renderer,changed_pixels=count,max_channel_delta=maximum,mean_channel_delta=total/len(a),bounds=bounds if count else [],width=width,height=height))
(evidence/'pixels.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps(rows,indent=2))
