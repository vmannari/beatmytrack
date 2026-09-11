#!/usr/bin/env python3
"""Corrected Slicks 'N' Slide track renderer.

Key finding: the .SS block_id indexes the SLICKS.DAT bitmap resource stream
DIRECTLY from resource 0. Earlier experiments incorrectly treated resource 24
as block 0, shifting every block by 24.

Pixels with palette index 0 are transparent when compositing track pieces.
The track canvas is filled with palette index 2 (the game's road/asphalt grey).
"""
from pathlib import Path
from PIL import Image, ImageDraw
import argparse, sys

# Keep this script self-contained for the supplied toolkit.
def be16(b: bytes) -> int:
    return int.from_bytes(b, 'big')

def c_string(data: bytes, off: int):
    end = data.index(0, off)
    return data[off:end].decode('cp437', errors='replace'), end + 1

def parse_ss_v2(path: Path):
    data = path.read_bytes()
    if data[:5] != b'\x00\x01SS~' or data[5] != 2:
        raise ValueError('Expected Slicks .SS format v2')
    off = 0x17A
    author, off = c_string(data, off)
    owner, off = c_string(data, off)
    off += 8
    n = be16(data[off:off+2]); off += 2
    blocks=[]
    for _ in range(n):
        r=data[off:off+5]; off+=5
        blocks.append({
            'x':be16(r[:2]), 'y':r[2], 'block_id':r[3],
            'rotation':r[4]&3, 'flags':r[4]&0xFC
        })
    return {'author':author,'owner':owner,'blocks':blocks,'block_count':n}

def decode_one(data: bytes, off: int, rid: int):
    if off >= len(data): return None
    mode=data[off]
    if mode==0:
        if off+3>len(data): return None
        w,h=data[off+1],data[off+2]
        if not w or not h: return None
        end=off+3+w*h
        if end>len(data): return None
        return {'id':rid,'off':off,'mode':mode,'w':w,'h':h,'pix':data[off+3:end],'end':end}
    if mode==2:
        if off+4>len(data): return None
        w,h,esc=data[off+1],data[off+2],data[off+3]
        if not w or not h: return None
        target=w*h; out=bytearray(); i=off+4
        while i<len(data) and len(out)<target:
            b=data[i]; i+=1
            if b==esc:
                if i+1>=len(data): return None
                count,val=data[i],data[i+1]; i+=2
                out.extend([val]*count)
            else:
                out.append(b)
        if len(out)<target: return None
        return {'id':rid,'off':off,'mode':mode,'w':w,'h':h,'pix':bytes(out[:target]),'end':i}
    return None

def parse_dat(path: Path):
    data=path.read_bytes(); off=0; resources=[]
    while True:
        r=decode_one(data,off,len(resources))
        if r is None: break
        resources.append(r); off=r['end']
    if data[off:off+3] != b'\xff\xff\xff':
        raise ValueError(f'Unexpected end of bitmap stream at 0x{off:X}')
    raw=data[off+3:off+3+768]
    if len(raw)!=768: raise ValueError('Truncated palette')
    palette=[tuple(min(255,c*4) for c in raw[i:i+3]) for i in range(0,768,3)]
    return resources,palette

def sprite(r,palette,rotation):
    im=Image.new('RGBA',(r['w'],r['h']),(0,0,0,0)); px=im.load()
    for y in range(r['h']):
        for x in range(r['w']):
            idx=r['pix'][y*r['w']+x]
            if idx != 0: # index 0 is transparent in track-piece blitting
                px[x,y]=(*palette[idx],255)
    if rotation:
        im=im.rotate(-90*rotation,expand=True,resample=Image.Resampling.NEAREST)
    return im

def render(track: Path, dat: Path, out: Path, diagnostics=False):
    t=parse_ss_v2(track); resources,palette=parse_dat(dat)
    # Road/asphalt background used by the game. Palette index 2 = ~156 grey.
    canvas=Image.new('RGBA',(320,200),(*palette[2],255))
    for o in t['blocks']:
        rid=o['block_id']
        if rid>=len(resources):
            raise ValueError(f'Block ID {rid} has no DAT resource')
        im=sprite(resources[rid],palette,o['rotation'])
        canvas.alpha_composite(im,(o['x'],o['y']))
    if diagnostics:
        d=ImageDraw.Draw(canvas)
        # Only visual-block diagnostics here; route parsing omitted intentionally.
        d.text((4,4),f'{track.name}: {t["block_count"]} blocks',fill=(255,255,0,255))
    canvas.convert('RGB').save(out)

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('track',type=Path)
    ap.add_argument('dat',type=Path)
    ap.add_argument('output',type=Path)
    args=ap.parse_args()
    render(args.track,args.dat,args.output)
