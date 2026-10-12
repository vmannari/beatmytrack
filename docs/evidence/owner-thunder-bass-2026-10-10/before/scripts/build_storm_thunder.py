"""Cleared thunder recording, mastered offline for the overhead storm scene."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import urllib.request
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'build/storm_thunder_sources'
PAGE='https://bigsoundbank.com/thunder-3-s3114.html'
MEDIA='https://bigsoundbank.com/UPLOAD/bwf-en/3114.wav'
RATE=44100
SOURCE_SHA256='448d45edf4022a0ac979a076e997321abcef3807cc8f41dcae2be2e317360255'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--fetch',action='store_true');args=parser.parse_args()
    SOURCE.mkdir(parents=True,exist_ok=True)
    master=SOURCE/'thunder-3114.wav'
    if args.fetch:
        html=urllib.request.urlopen(PAGE,timeout=30).read()
        if b'CC0' not in html or b'Joseph SARDIN' not in html: raise ValueError('Expected CC0 recording metadata')
        (SOURCE/'license.html').write_bytes(html)
        if not master.exists(): master.write_bytes(urllib.request.urlopen(MEDIA,timeout=45).read())
    data=master.read_bytes()
    digest=hashlib.sha256(data).hexdigest()
    if digest!=SOURCE_SHA256: raise ValueError('Thunder source hash changed')
    receipt=SOURCE/'source.json'
    if receipt.exists() and json.loads(receipt.read_text())['sha256']!=digest: raise ValueError('Pinned thunder source changed')
    receipt.write_text(json.dumps({'source':PAGE,'download':MEDIA,'license':'CC0-1.0','author':'Joseph SARDIN & Axeline T.','sha256':digest},indent=2)+'\n')
    pos=12
    while pos+8<=len(data):
        kind,count=struct.unpack_from('<4sI',data,pos);body=data[pos+8:pos+8+count]
        if kind==b'fmt ':
            fmt,channels,rate,_,_,bits=struct.unpack_from('<HHIIHH',body)
            if fmt==65534: fmt=struct.unpack_from('<H',body,24)[0]
        elif kind==b'data': pcm=body
        pos+=8+count+(count&1)
    if fmt!=1 or bits not in [16,24]: raise ValueError('Expected PCM source')
    if bits==24:
        raw=np.frombuffer(pcm,dtype=np.uint8).reshape(-1,3).astype(np.int32)
        ints=raw[:,0]|(raw[:,1]<<8)|(raw[:,2]<<16)
        values=((ints^0x800000)-0x800000)/8388608.0
    else: values=np.frombuffer(pcm,dtype='<i2').astype(np.float64)/32768.0
    values=values.reshape(-1,channels).mean(axis=1)
    # Start at the first sustained thunder energy, avoiding recording pre-roll.
    hop=round(rate*.02)
    rms=np.array([np.sqrt(np.mean(values[i:i+hop]**2)) for i in range(0,len(values)-hop,hop)])
    active=np.flatnonzero(rms>max(float(rms.max())*.12,.001))
    start=max(0,int(active[0])*hop-round(.08*rate)) if len(active) else 0
    values=values[start:start+round(7.5*rate)]
    coordinates=np.arange(round(len(values)*RATE/rate),dtype=np.float64)*rate/RATE
    values=np.interp(coordinates,np.arange(len(values),dtype=np.float64),values)
    hz=np.fft.rfftfreq(len(values),1/RATE)
    spectrum=np.fft.rfft(values)*(1-np.exp(-(hz/45)**4))*np.exp(-(hz/3200)**4)
    values=np.fft.irfft(spectrum,n=len(values));values-=values.mean()
    # Fuller sustained thunder: control isolated peaks before loudness matching
    # so the rolling body can be strong without exhausting the output ceiling.
    knee=max(np.sqrt(np.mean(values**2))*3.0,1e-8)
    values=np.tanh(values/knee)*knee
    attack=round(.015*RATE);release=min(round(1.0*RATE),len(values)//3)
    values[:attack]*=np.linspace(0,1,attack);values[-release:]*=np.linspace(1,0,release)
    values*=min(.22/max(np.sqrt(np.mean(values**2)),1e-8),.84/max(np.max(np.abs(values)),1e-8))
    pcm=np.rint(values*32767).astype('<i2')
    target=ROOT/'game/assets/audio/storm_thunder.wav'
    with wave.open(str(target),'wb') as handle:
        handle.setnchannels(1);handle.setsampwidth(2);handle.setframerate(RATE);handle.writeframes(pcm.tobytes())
    settings=target.with_suffix('.wav.import')
    settings.write_text(settings.read_text().replace('compress/mode=2','compress/mode=0'),encoding='utf-8')
    manifest=dict(file=target.name,source=PAGE,download=MEDIA,author='Joseph SARDIN & Axeline T.',license='CC0-1.0',
        source_sha256=digest,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),source_start_seconds=start/rate,
        rate=RATE,channels=1,bits=16,seconds=len(pcm)/RATE,bytes=target.stat().st_size,
        edits='sustained-onset7.5s excerpt; mono44.1kHz;45Hz-3.2kHz softening; soft peak control for stronger body;15ms attack/1s release; RMS .22/peak cap .84',
        rms_dbfs=float(20*np.log10(np.sqrt(np.mean(values**2)))),peak_dbfs=float(20*np.log10(np.max(np.abs(values)))))
    (target.parent/'storm_thunder_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__': main()
