"""Bake original surface colour factors; no runtime generation or external assets.

Channels: R asphalt multiplier encoded over [0.8,1.2], G directional grain,
B sand multiplier over [0.8,1.2]. Seamless 32 m tile, 2x supersampling.
Requires the existing development numpy installation; PNG uses stdlib only.
"""
from pathlib import Path
import struct, zlib
import numpy as np

SIZE, TILE = 1024, 32.0
n = SIZE * 2
y, x = np.mgrid[:n, :n].astype(np.float32)
x = (x + .5) * TILE / n
y = (y + .5) * TILE / n
def fract(v): return v - np.floor(v)
def smooth(a,b,v):
    t = np.clip((v-a)/(b-a),0,1)
    return t*t*(3-2*t)
def noise(f, ox=0., oy=0.):
    period = max(1,round(f*TILE))
    px, py = x*period/TILE+ox, y*period/TILE+oy
    ix, iy = np.floor(px), np.floor(py)
    fx, fy = smooth(0,1,fract(px)), smooth(0,1,fract(py))
    def h(dx,dy):
        a = fract(((ix+dx)%period)*.1031)
        b = fract(((iy+dy)%period)*.1031)
        c = a.copy()
        d = a*(b+33.33)+b*(c+33.33)+c*(a+33.33)
        a,b,c = a+d,b+d,c+d
        return fract((a+b)*c)
    return (h(0,0)*(1-fx)+h(1,0)*fx)*(1-fy)+(h(0,1)*(1-fx)+h(1,1)*fx)*fy

# Retain subtle binder variation and mineral contrast; omit repair/crack shapes.
base = 1.015+(noise(.052,17.4,6.1)-.5)*.035+(noise(.115,3.7,29.2)-.5)*.03+(noise(.63,41.2,9.6)-.5)*.045
density = noise(1.3,11.4,7.2)
grain = noise(17.)
mineral = smooth(.535,.605,grain)
pores = 1-smooth(.265,.335,grain)
chips = smooth(.685,.755,noise(7.3,27.1,13.7))
asphalt = base*(1+((mineral-.32)*.085-(pores-.14)*.045)*(.45+1.15*density)+(chips-.08)*.022)
grit = noise(8.7,31.4,7.1)
sand = .965+(noise(.65,8.3,21.7)-.5)*.045+(noise(4.3,19.2,3.8)-.5)*.045+(noise(19.)-.5)*.12+smooth(.58,.82,noise(19.))*.04-smooth(.685,.885,grit)*.16
pixels = np.stack(((asphalt-.8)/.4,noise(2.8),(sand-.8)/.4),axis=-1)
pixels = pixels.reshape(SIZE,2,SIZE,2,3).mean(axis=(1,3))
pixels = np.rint(np.clip(pixels,0,1)*255).astype(np.uint8)
def chunk(kind,data):
    return struct.pack('!I',len(data))+kind+data+struct.pack('!I',zlib.crc32(kind+data)&0xffffffff)
raw = b''.join(b'\0'+row.tobytes() for row in pixels)
png = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',SIZE,SIZE,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
path = Path(__file__).resolve().parents[1]/'game/assets/textures/surface_factors_v1.png'
path.write_bytes(png)
print(f'{path}: {len(png)} bytes; tile={TILE}m; mean factors asphalt={asphalt.mean():.4f} sand={sand.mean():.4f}')
