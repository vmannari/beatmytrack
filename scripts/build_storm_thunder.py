"""Master the owner-supplied thunder recording with a low-frequency boost."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'build/storm_thunder_sources'
SOURCE_NAME='freesound_community-thunder-big-wav-29190.mp3'
RATE=44100
SOURCE_SHA256='12b96eaaae5e4528237bb67b7dcc9eeb4a00e3dcc11d424b29146cd71007c0ca'

def main():
    SOURCE.mkdir(parents=True,exist_ok=True)
    data=(SOURCE/'owner-thunder-29190.mp3').read_bytes()
    digest=hashlib.sha256(data).hexdigest()
    if digest!=SOURCE_SHA256: raise ValueError('Owner thunder source hash changed')
    meta=json.loads((SOURCE/'owner-thunder-29190.decode.json').read_text())
    decoded=(SOURCE/'owner-thunder-29190.f32').read_bytes()
    if hashlib.sha256(decoded).hexdigest()!=meta['sha256']: raise ValueError('Decoded source differs from receipt')
    rate=int(meta['rate'])
    values=np.frombuffer(decoded,dtype='<f4').astype(np.float64)
    # Start just before the main clap, then keep a bounded rumble tail.
    hop=round(.02*rate)
    envelope=np.array([np.sqrt(np.mean(values[i:i+hop]**2)) for i in range(0,len(values)-hop,hop)])
    active=np.flatnonzero(envelope>max(float(envelope.max())*.30,.001))
    start=max(0,int(active[0])*hop-round(.06*rate)) if len(active) else 0
    values=values[start:start+round(6.0*rate)]
    coordinates=np.arange(round(len(values)*RATE/rate),dtype=np.float64)*rate/RATE
    values=np.interp(coordinates,np.arange(len(values),dtype=np.float64),values)
    hz=np.fft.rfftfreq(len(values),1/RATE)
    # +6dB low shelf below180Hz; gentle25Hz subsonic cleanup.
    shelf=10**((6.0/(1+(hz/180.0)**4))/20.0)
    spectrum=np.fft.rfft(values)*shelf*(1-np.exp(-(hz/25)**4))
    values=np.fft.irfft(spectrum,n=len(values));values-=values.mean()
    # Fuller sustained thunder: control isolated peaks before loudness matching
    # so the rolling body can be strong without exhausting the output ceiling.
    knee=max(np.sqrt(np.mean(values**2))*3.0,1e-8)
    values=np.tanh(values/knee)*knee
    attack=round(.015*RATE);release=min(round(1.20*RATE),len(values)//3)
    values[:attack]*=np.linspace(0,1,attack)
    values[-release:]*=.5+.5*np.cos(np.linspace(0,np.pi,release))
    # Give the rolling body more presence after the main clap; keep its short
    # cosine tail and bounded peak rather than extending the sound.
    time=np.arange(len(values),dtype=np.float64)/RATE
    rise=np.clip((time-.65)/.45,0.0,1.0)
    values*=1.0+rise*rise*(3.0-2.0*rise)
    body_knee=max(np.sqrt(np.mean(values**2))*2.5,1e-8)
    values=np.tanh(values/body_knee)*body_knee
    values*=min(.30/max(np.sqrt(np.mean(values**2)),1e-8),.84/max(np.max(np.abs(values)),1e-8))
    pcm=np.rint(values*32767).astype('<i2')
    target=ROOT/'game/assets/audio/storm_thunder.wav'
    with wave.open(str(target),'wb') as handle:
        handle.setnchannels(1);handle.setsampwidth(2);handle.setframerate(RATE);handle.writeframes(pcm.tobytes())
    settings=target.with_suffix('.wav.import')
    settings.write_text(settings.read_text().replace('compress/mode=2','compress/mode=0'),encoding='utf-8')
    manifest=dict(file=target.name,source='Owner-supplied local MP3,2026-10-10',source_filename=SOURCE_NAME,
        author='freesound_community (filename attribution)',license='Owner-supplied; original licence metadata not provided',
        source_sha256=digest,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),source_start_seconds=start/rate,decoded_sha256=meta['sha256'],source_seconds=meta['source_seconds'],bass_shelf_db=6.0,bass_shelf_hz=180,
        rate=RATE,channels=1,bits=16,seconds=len(pcm)/RATE,bytes=target.stat().st_size,
        edits='main-clap onset6s excerpt; mono44.1kHz; +6dB low shelf below180Hz/25Hz cleanup; soft peak control; rumble lift after650ms;15ms attack/1.2s cosine release; RMS .30/peak cap .84; no added layers',
        rms_dbfs=float(20*np.log10(np.sqrt(np.mean(values**2)))),peak_dbfs=float(20*np.log10(np.max(np.abs(values)))))
    (target.parent/'storm_thunder_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__': main()
