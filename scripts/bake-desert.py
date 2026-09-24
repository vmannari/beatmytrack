"""Original periodic dune/sand data, not copied from reference photographs.

32 m tile. R: dune height, G/B: signed x/z slope encoded into 0..1.
1024 data texture with offline 4x antialiasing. Existing development numpy only.
The shader samples baked data; it does not run noise, trig or terrain physics.
"""
from pathlib import Path
import struct
import zlib
import numpy as np

SIZE, N, TILE = 1024, 2048, 32.0
rng = np.random.default_rng(240924)
y, x = np.mgrid[:N, :N].astype(np.float32)/N

def noise(period):
    grid = rng.random((period,period)).astype(np.float32)
    px, py = x*period, y*period
    ix, iy = px.astype(int), py.astype(int)
    fx, fy = px%1, py%1
    fx, fy = fx*fx*(3-2*fx), fy*fy*(3-2*fy)
    return ((1-fx)*grid[iy,ix]+fx*grid[iy,(ix+1)%period])*(1-fy)+((1-fx)*grid[(iy+1)%period,ix]+fx*grid[(iy+1)%period,(ix+1)%period])*fy

tau = np.pi*2
warp = (noise(3)-.5)*1.0 + (noise(7)-.5)*.22
phase = tau*(x*4+y*2+warp)
# Curving, asymmetric leeward faces. Softer swales break continuous stripes.
ridge = np.sin(phase)+.30*np.sin(phase*2+.8)+.10*np.sin(phase*3+1.1)
coverage = .30+.70*noise(4)
large = ridge*coverage*.42 + (noise(2)-.5)*.6
# Smaller wind ripples bend around the large crests, with broad swept gaps.
ripple_phase = tau*(x*42+y*18+warp*3.5)
ripple = (np.sin(ripple_phase)+.25*np.sin(ripple_phase*2+.7))*.018*(.25+noise(6)*.75)
height = large+ripple
dx = (np.roll(height,-1,1)-np.roll(height,1,1))/(TILE/N*2)
dy = (np.roll(height,-1,0)-np.roll(height,1,0))/(TILE/N*2)
pixels = np.stack((np.clip(.5+large*.60,0,1),np.clip(.5+dx*.45,0,1),np.clip(.5+dy*.45,0,1)),axis=-1)
pixels = pixels.reshape(SIZE,2,SIZE,2,3).mean(axis=(1,3))
pixels = np.rint(pixels*255).astype(np.uint8)
def chunk(kind,data):
    return struct.pack('!I',len(data))+kind+data+struct.pack('!I',zlib.crc32(kind+data)&0xffffffff)
raw = b''.join(b'\0'+row.tobytes() for row in pixels)
png = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',SIZE,SIZE,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
path=Path(__file__).resolve().parents[1]/'game/assets/textures/desert_dunes_v1.png'
path.write_bytes(png)
print(f'{path}: {len(png)} bytes; {TILE}m periodic tile; height {height.min():.3f}..{height.max():.3f}m (visual only)')
