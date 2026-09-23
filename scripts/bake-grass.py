"""Original seamless grass maps. Development-only numpy; no downloaded assets.

Albedo: 4 m tile with 30–60 cm blade fans. Macro: 32 m tile, 4–10 m patches.
Normal: 0.8 m tile with 5–10 cm relief. All maps are baked, never runtime noise.
"""
from pathlib import Path
import struct
import zlib
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'game/assets/textures'
N = 512
rng = np.random.default_rng(230923)
y, x = np.mgrid[:N, :N] / N

def noise(period):
    grid = rng.random((period, period))
    px, py = x * period, y * period
    ix, iy = px.astype(int), py.astype(int)
    fx, fy = px % 1, py % 1
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    return ((1-fx)*grid[iy,ix]+fx*grid[iy,(ix+1)%period])*(1-fy) + ((1-fx)*grid[(iy+1)%period,ix]+fx*grid[(iy+1)%period,(ix+1)%period])*fy

def save(name, pixels):
    pixels = np.rint(np.clip(pixels, 0, 1)*255).astype(np.uint8)
    def chunk(kind, data):
        return struct.pack('!I',len(data))+kind+data+struct.pack('!I',zlib.crc32(kind+data)&0xffffffff)
    raw = b''.join(b'\0'+row.tobytes() for row in pixels)
    png = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',N,N,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
    (OUT / name).write_bytes(png)
    print(name, len(png), 'bytes')

macro = np.clip(.5 + (noise(5)-.5)*1.15 + (noise(9)-.5)*.65 + (noise(17)-.5)*.22,0,1)
save('grass_macro_mask.png', np.stack((macro,noise(4),noise(7)),axis=-1))
shade = .5 + (noise(9)-.5)*.10
for i in range(150):
    cx, cy = rng.random(2)
    angle = rng.uniform(0, 2*np.pi)
    for blade in range(4):
        a = angle + (blade-1.5)*.42
        dx, dy = (x-cx+.5)%1-.5, (y-cy+.5)%1-.5
        u, v = dx*np.cos(a)+dy*np.sin(a), -dx*np.sin(a)+dy*np.cos(a)
        length = rng.uniform(.045,.12)
        width = .006*np.clip(1-u/length,0,1)
        stroke = np.clip(1-np.abs(v)/np.maximum(width,.0001),0,1)*(u>0)*(u<length)
        shade += stroke*rng.uniform(-.08,.08)
save('grass_albedo.png', np.stack((shade,shade,shade),axis=-1))
height = noise(11)*.7 + noise(17)*.3
dx = (np.roll(height,-1,1)-np.roll(height,1,1))*6
dy = (np.roll(height,-1,0)-np.roll(height,1,0))*6
normal = np.stack((-dx,-dy,np.ones_like(dx)),axis=-1)
normal /= np.linalg.norm(normal,axis=-1,keepdims=True)
save('grass_normal.png',normal*.5+.5)
