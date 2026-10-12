"""Fetch/master a cleared field-recorded rain loop; build tools only."""
from pathlib import Path
import argparse
import hashlib
import json
import urllib.request
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/storm_rain_sources"
OUT = ROOT / "game/assets/audio/ambience"
PAGE = "https://freesound.org/people/jmbphilmes/sounds/200271/"
MEDIA = "https://cdn.freesound.org/previews/200/200271_2322692-hq.mp3"
RATE = 44100
SOURCE_SHA256 = "9150f775fea3c4aa020edff9174fb0d1a1d4c5cfe464a0ce6f3dd414065005be"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    master = SOURCE / "rural-rain-200271.mp3"
    if args.fetch:
        html = urllib.request.urlopen(PAGE, timeout=30).read()
        if b"creativecommons.org/publicdomain/zero/1.0" not in html or b"jmbphilmes" not in html:
            raise ValueError("Expected CC0 recording/author metadata")
        (SOURCE / "rural-rain-license.html").write_bytes(html)
        if not master.exists():
            master.write_bytes(urllib.request.urlopen(MEDIA, timeout=45).read())
    data = master.read_bytes()
    if hashlib.sha256(data).hexdigest()!=SOURCE_SHA256:
        raise ValueError("Rain source hash changed; review the source before rebuilding")
    if args.fetch:
        print("Source pinned. Decode with scripts/dev.ps1 TestScript -ScriptPath res://tests/decode_storm_rain_source.gd, then rebuild without --fetch.")
        return
    decoded = SOURCE / "rural-rain-200271.f32"
    meta = json.loads((SOURCE/"rural-rain-200271.decode.json").read_text())
    decoded_data = decoded.read_bytes()
    if hashlib.sha256(decoded_data).hexdigest()!=meta['sha256']:
        raise ValueError("Decoded recording hash differs from decoder receipt")
    rate = int(meta['rate'])
    source_values = np.frombuffer(decoded_data,dtype='<f4').astype(np.float64)
    # Four distinct areas of the rural recording merge individual local drops
    # into a broad rain field. No synthetic hiss or room/cavern reverb.
    count = round(25*rate)
    offsets = [8.0,18.37,34.13,49.79]
    if len(source_values)<round((offsets[-1]+25)*rate): raise ValueError("Rain recording is too short")
    values = sum(source_values[round(start*rate):round(start*rate)+count] for start in offsets)*0.25
    coordinates = np.arange(round(len(values)*RATE/rate),dtype=np.float64)*rate/RATE
    values = np.interp(coordinates,np.arange(len(values),dtype=np.float64),values)
    hz = np.fft.rfftfreq(len(values),1/RATE)
    spectrum = np.fft.rfft(values)
    spectrum *= (1-np.exp(-(hz/100)**4))*np.exp(-(hz/2200)**4)
    values = np.fft.irfft(spectrum,n=len(values))
    values = np.tanh(values/max(np.sqrt(np.mean(values**2))*3.5,1e-8))
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
    manifest = dict(file=target.name,source=PAGE,download=MEDIA,author='jmbphilmes',license='CC0-1.0',
        source_sha256=hashlib.sha256(data).hexdigest(),decoded_sha256=meta['sha256'],quality='public HQ MP3 preview decoded by pinned Godot 4.7.2',sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        rate=RATE,channels=1,bits=16,seconds=len(pcm)/RATE,bytes=target.stat().st_size,
        edits='four 25s rural rain regions (8/18.37/34.13/49.79s) mixed; mono; 44.1kHz; 100Hz-2.2kHz distance softening; soft transient limiting; 1s cyclic crossfade; RMS .055, peak cap .30',
        rms_dbfs=float(20*np.log10(np.sqrt(np.mean(values**2)))),peak_dbfs=float(20*np.log10(np.max(np.abs(values)))))
    (OUT/'storm_rain_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))

if __name__ == '__main__': main()
