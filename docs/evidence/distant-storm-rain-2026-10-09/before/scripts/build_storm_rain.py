"""Fetch/master a cleared field-recorded rain loop; build tools only."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import urllib.request
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/storm_rain_sources"
OUT = ROOT / "game/assets/audio/ambience"
PAGE = "https://bigsoundbank.com/rain-on-concrete-s1289.html"
MEDIA = "https://bigsoundbank.com/UPLOAD/bwf-en/1289.wav"
RATE = 44100
SOURCE_SHA256 = "e4876e37514c40728637c6caaed6068209c00f77b80557752f237bb02c7bdbef"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    master = SOURCE / "rain-1289.wav"
    if args.fetch:
        html = urllib.request.urlopen(PAGE, timeout=30).read()
        if b"CC0" not in html or b"Joseph SARDIN" not in html:
            raise ValueError("Expected CC0 recording/author metadata")
        (SOURCE / "license.html").write_bytes(html)
        if not master.exists():
            master.write_bytes(urllib.request.urlopen(MEDIA, timeout=45).read())
    data = master.read_bytes()
    if hashlib.sha256(data).hexdigest()!=SOURCE_SHA256:
        raise ValueError("Rain source hash changed; review the source before rebuilding")
    pos = 12
    while pos + 8 <= len(data):
        kind, count = struct.unpack_from("<4sI", data, pos)
        body = data[pos+8:pos+8+count]
        if kind == b"fmt ":
            fmt, channels, rate, _, _, bits = struct.unpack_from("<HHIIHH", body)
            if fmt == 65534: fmt = struct.unpack_from("<H", body, 24)[0]
        elif kind == b"data": pcm = body
        pos += 8 + count + (count & 1)
    if fmt != 1 or bits not in [16,24]: raise ValueError("Expected recorded PCM")
    if bits == 24:
        raw = np.frombuffer(pcm,dtype=np.uint8).reshape(-1,3).astype(np.int32)
        ints = raw[:,0] | (raw[:,1]<<8) | (raw[:,2]<<16)
        values = ((ints ^ 0x800000)-0x800000)/8388608.0
    else: values = np.frombuffer(pcm,dtype='<i2').astype(np.float64)/32768.0
    values = values.reshape(-1,channels).mean(axis=1)
    values = values[round(20*rate):round(40*rate)]
    coordinates = np.arange(round(len(values)*RATE/rate),dtype=np.float64)*rate/RATE
    values = np.interp(coordinates,np.arange(len(values),dtype=np.float64),values)
    hz = np.fft.rfftfreq(len(values),1/RATE)
    spectrum = np.fft.rfft(values)
    spectrum *= (1-np.exp(-(hz/140)**4))*np.exp(-(hz/6500)**4)
    values = np.fft.irfft(spectrum,n=len(values))
    # Tame close-microphone drop transients so isolated drops do not set the
    # entire loop's quietness or punctuate the background with sharp knocks.
    values = np.tanh(values/max(np.sqrt(np.mean(values**2))*3.0,1e-8))
    overlap = RATE
    ramp = .5-.5*np.cos(np.linspace(0,np.pi,overlap))
    joined = values[-overlap:]*(1-ramp)+values[:overlap]*ramp
    values = np.concatenate([values[overlap:-overlap],joined])
    values -= values.mean()
    values *= min(.08/max(np.sqrt(np.mean(values**2)),1e-8),.5/max(np.max(np.abs(values)),1e-8))
    pcm = np.rint(values*32767).astype('<i2')
    OUT.mkdir(parents=True,exist_ok=True)
    target = OUT/'storm_rain_recorded.wav'
    with wave.open(str(target),'wb') as handle:
        handle.setnchannels(1); handle.setsampwidth(2); handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())
    settings = target.with_suffix('.wav.import')
    if not settings.exists(): settings.write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\ncompress/mode=0\n',encoding='utf-8')
    manifest = dict(file=target.name,source=PAGE,download=MEDIA,author='Joseph SARDIN',license='CC0-1.0',
        source_sha256=hashlib.sha256(data).hexdigest(),sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        rate=RATE,channels=1,bits=16,seconds=len(pcm)/RATE,bytes=target.stat().st_size,
        edits='20-40s recording; mono; 44.1kHz; 140Hz-6.5kHz softening; soft drop-transient limiting; 1s cyclic crossfade; RMS .08, peak cap .5',
        rms_dbfs=float(20*np.log10(np.sqrt(np.mean(values**2)))),peak_dbfs=float(20*np.log10(np.max(np.abs(values)))))
    (OUT/'storm_rain_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))

if __name__ == '__main__': main()
