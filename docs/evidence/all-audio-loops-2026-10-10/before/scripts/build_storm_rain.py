"""Master a short cyclic loop from the owner's rain recording; build tools only."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/storm_rain_sources"
OUT = ROOT / "game/assets/audio/ambience"
SOURCE_NAME = "dragon-studio-copyright-free-rain-sounds-331497.mp3"
RATE = 44100
SOURCE_SHA256 = "1142dde3666dad8d65e163eaca9292edcb7710afa4b81a9b7cbb93dab1a10e0c"

def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    master = SOURCE / "owner-rain-331497.mp3"
    data = master.read_bytes()
    if hashlib.sha256(data).hexdigest()!=SOURCE_SHA256:
        raise ValueError("Rain source hash changed; review the source before rebuilding")
    decoded = SOURCE / "owner-rain-331497.f32"
    meta = json.loads((SOURCE/"owner-rain-331497.decode.json").read_text())
    decoded_data = decoded.read_bytes()
    if hashlib.sha256(decoded_data).hexdigest()!=meta['sha256']:
        raise ValueError("Decoded recording hash differs from decoder receipt")
    rate = int(meta['rate'])
    source_values = np.frombuffer(decoded_data,dtype='<f4').astype(np.float64)
    if float(meta['start_seconds'])!=20.0 or float(meta['seconds'])!=21.0:
        raise ValueError("Decode the chosen20-41s excerpt")
    # Preserve the supplied texture: no EQ or added layers.
    values = source_values
    coordinates = np.arange(round(len(values)*RATE/rate),dtype=np.float64)*rate/RATE
    values = np.interp(coordinates,np.arange(len(values),dtype=np.float64),values)
    values -= values.mean()
    # A few isolated source peaks otherwise force the whole rain bed inaudibly
    # quiet. Gentle peak control retains the flow while matching the old level.
    knee = max(np.sqrt(np.mean(values**2))*4.0,1e-8)
    values = np.tanh(values/knee)*knee
    overlap = RATE
    ramp = .5-.5*np.cos(np.linspace(0,np.pi,overlap))
    joined = values[-overlap:]*(1-ramp)+values[:overlap]*ramp
    values = np.concatenate([values[overlap:-overlap],joined])
    values -= values.mean()
    values *= min(.055/max(np.sqrt(np.mean(values**2)),1e-8),.30/max(np.max(np.abs(values)),1e-8))
    pcm = np.rint(values*32767).astype('<i2')
    OUT.mkdir(parents=True,exist_ok=True)
    target = OUT/'storm_rain_recorded.wav'
    with wave.open(str(target),'wb') as handle:
        handle.setnchannels(1); handle.setsampwidth(2); handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())
    settings = target.with_suffix('.wav.import')
    if not settings.exists(): settings.write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\ncompress/mode=0\n',encoding='utf-8')
    manifest = dict(file=target.name,source='Owner-supplied local MP3,2026-10-10',source_filename=SOURCE_NAME,
        author='Dragon Studio (filename attribution)',license='Owner-supplied; original licence metadata not provided',
        source_sha256=hashlib.sha256(data).hexdigest(),decoded_sha256=meta['sha256'],quality='owner MP3 decoded by pinned Godot4.7.2',sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        source_seconds=meta['source_seconds'],source_start_seconds=20,source_excerpt_seconds=21,
        rate=RATE,channels=1,bits=16,seconds=len(pcm)/RATE,bytes=target.stat().st_size,
        edits='20-41s excerpt; mono44.1kHz PCM; DC removal; gentle peak control;1s cosine cyclic crossfade; RMS .055, peak cap .30; no EQ or added layers',
        rms_dbfs=float(20*np.log10(np.sqrt(np.mean(values**2)))),peak_dbfs=float(20*np.log10(np.max(np.abs(values)))))
    (OUT/'storm_rain_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))

if __name__ == '__main__': main()
