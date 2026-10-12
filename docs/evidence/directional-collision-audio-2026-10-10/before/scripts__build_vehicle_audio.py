"""Offline mastering of cleared recordings; NumPy is a build tool, never a game dependency."""
from pathlib import Path
import hashlib
import json
import math
import struct
import wave
import argparse
import numpy as np

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--compact-only", action="store_true", help="Rebuild only the compact's six engine loops")
args = parser.parse_args()

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/vehicle_audio_sources"
OUT = ROOT / "game/assets/audio/vehicles"
RATE = 44100
OUT.mkdir(parents=True, exist_ok=True)
sources = json.loads((SOURCE / "source_manifest.json").read_text(encoding="utf-8"))
sources += json.loads((SOURCE / "surface_source_manifest.json").read_text(encoding="utf-8"))
source_map = {item["filename"]: item for item in sources}
outputs = []
from audio_loop_mastering import crossfade, level_texture, engine_sustain, coherent_orders
TEXTURES = {"road","tire","wind","water","wet_road","sand_roll","sand","loose","grass","sand_debris"}


def read(name):
    data = (SOURCE / name).read_bytes()
    if hashlib.sha256(data).hexdigest() != source_map[name]["sha256"]:
        raise ValueError("Source checksum changed: " + name)
    if data[:4] != b"RIFF": raise ValueError("Expected WAV master")
    pos = 12
    while pos + 8 <= len(data):
        kind, size = struct.unpack_from("<4sI", data, pos)
        body = data[pos + 8:pos + 8 + size]
        if kind == b"fmt ":
            fmt, channels, rate, _, _, bits = struct.unpack_from("<HHIIHH", body)
            if fmt == 65534: fmt = struct.unpack_from("<H", body, 24)[0]
        elif kind == b"data": pcm = body
        pos += 8 + size + (size & 1)
    if fmt == 3:
        values = np.frombuffer(pcm, dtype="<f4").astype(np.float64)
    elif bits == 24:
        raw = np.frombuffer(pcm, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        values = raw[:,0] | (raw[:,1] << 8) | (raw[:,2] << 16)
        values = ((values ^ 0x800000) - 0x800000) / 8388608.0
    elif bits == 16:
        values = np.frombuffer(pcm, dtype="<i2").astype(np.float64) / 32768.0
    elif bits == 32:
        values = np.frombuffer(pcm, dtype="<i4").astype(np.float64) / 2147483648.0
    else: raise ValueError("Unsupported PCM master")
    values = values.reshape(-1, channels).mean(axis=1)
    if rate != RATE:
        # NumPy 1.x defaults to int32 indexes on Windows. Multiplying those
        # indexes by 48,000/96,000 overflows after about one second and clamps
        # interpolation to a constant sample, baking repeating silence into loops.
        coordinates = np.arange(round(len(values)*RATE/rate),dtype=np.float64)*(float(rate)/RATE)
        if len(coordinates)>1 and not np.all(np.diff(coordinates)>0):
            raise ValueError("Resampling coordinates must advance continuously")
        values = np.interp(coordinates,np.arange(len(values),dtype=np.float64),values)
    return values


def filter_audio(values, low=35, high=9000, warmth=0.0):
    spectrum = np.fft.rfft(values)
    hz = np.fft.rfftfreq(len(values), 1/RATE)
    gain = (1-np.exp(-(hz/max(low,1))**4)) * np.exp(-(hz/high)**4)
    gain *= 1 + warmth*np.exp(-((hz-170)/180)**2)
    return np.fft.irfft(spectrum*gain,n=len(values))


def steady(values, seconds=3.2, start=None):
    count = min(round(seconds*RATE), len(values))
    if start is None:
        # Select steady energy, away from starts/stops and isolated mechanical clicks.
        candidates = range(round(.25*RATE), max(round(.25*RATE)+1,len(values)-count), round(.2*RATE))
        scored = []
        for offset in candidates:
            segment = values[offset:offset+count]
            blocks = np.array_split(segment,16)
            rms = np.array([np.sqrt(np.mean(b*b)) for b in blocks])
            score = np.mean(rms)/(1+4*np.std(rms)/(np.mean(rms)+1e-8))
            scored.append((score,offset))
        start_index = max(scored)[1] if scored else 0
    else: start_index = min(round(start*RATE),max(0,len(values)-count))
    return values[start_index:start_index+count].copy()


def loop(values):
    return crossfade(values,RATE)


def transpose(values, factor):
    return np.interp(np.arange(0,len(values)-1,factor),np.arange(len(values)),values)


def write(name, values, used, looping=True, rms=.14, engine_order=None, loop_ready=False):
    values = filter_audio(values) if engine_order is None else values.copy()
    values -= values.mean()
    impact = name.startswith("impact_")
    if impact:
        # Contact PCM starts at its strongest transient: no quiet pre-roll.
        values = values[int(np.argmax(np.abs(values))):].copy()
    if looping:
        if engine_order is None:
            values = loop(values)
            if name in TEXTURES:
                values = filter_audio(level_texture(values,RATE))
                values -= values.mean()
        else:
            from compact_audio_mastering import seam_loop
            # Final EQ sees the completed periodic waveform, not an open cut.
            values = filter_audio(values if loop_ready else seam_loop(values, RATE, engine_order))
            values -= values.mean()
        if name == "tire":
            # Keep the pinned zero-endpoint contract at a natural quiet crossing,
            # rather than inserting a repeated 4-ms fade-to-silence into the bed.
            crossings = np.flatnonzero(values[:-1]*values[1:]<=0)+1
            if not len(crossings): raise ValueError("Tire texture has no zero crossing")
            boundary = crossings[np.argmin(abs(values[crossings])+abs(values[crossings-1]))]
            values = np.roll(values,-int(boundary))
            values[0] = values[-1] = 0.0
    else:
        attack = 0 if impact else min(round(.003*RATE), len(values)//3)
        release = min(round(.06*RATE), len(values)//3)
        values[:attack] *= np.linspace(0,1,attack)
        values[-release:] *= np.linspace(1,0,release)
    values *= min(rms/max(np.sqrt(np.mean(values*values)),1e-8),.84/max(np.max(np.abs(values)),1e-8))
    if looping:
        windows = np.array_split(values,max(1,len(values)//round(.02*RATE)))
        envelope = np.array([np.sqrt(np.mean(window*window)) for window in windows])
        if np.min(envelope)<max(.0003,np.median(envelope)*.04):
            raise ValueError("Do not ship an interrupted loop: "+name)
    # Deterministic TPDF dither for 24 -> 16 bit conversion.
    rng = np.random.default_rng(6102026)
    pcm = np.clip(np.rint(values*32767 + (rng.random(len(values))-rng.random(len(values)))*.5),-32767,32767).astype("<i2")
    if name == "tire": pcm[0] = pcm[-1] = 0
    target = OUT / (name + ".wav")
    with wave.open(str(target),"wb") as handle:
        handle.setnchannels(1); handle.setsampwidth(2); handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())
    # QOA is Godot's default WAV import. Engine loops use lossless PCM so loop
    # frame counts and repeated pitch changes retain the mastered waveform.
    import_path = target.with_suffix(".wav.import")
    if import_path.exists():
        settings = import_path.read_text(encoding="utf-8")
        import re
        settings = re.sub(r"compress/mode=\d+", "compress/mode=0", settings)
        import_path.write_text(settings,encoding="utf-8")
    else:
        import_path.write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\ncompress/mode=0\n',encoding="utf-8")
    outputs.append({"file":target.name,"sources":used,"loop":looping,"seconds":len(values)/RATE,"rms_dbfs":20*math.log10(max(np.sqrt(np.mean(values*values)),1e-9)),"peak_dbfs":20*math.log10(max(np.max(np.abs(values)),1e-9)),"seam_step":float(abs(values[0]-values[-1])) if looping else None,"sha256":hashlib.sha256(target.read_bytes()).hexdigest()})
    if engine_order is not None: outputs[-1]["engine_order_hz"] = engine_order
    if name in TEXTURES: outputs[-1]["continuous_texture"] = True


truck_low = "Vehicle_Truck_Idle_Exterior_Rear_Loop_Stereo_01.wav"
truck_mid = "Vehicle_Truck_Drive_Exterior_Loop_Stereo_01.wav"
profiles = {
    "pickup": [(truck_low,.90,.45),(truck_mid,.85,.45),(truck_mid,1.45,.35)],
    "classic": [("0534.wav",1.0,.25),("0534.wav",1.55,.2),("0534.wav",2.3,.15)],
    "formula": [("0290.wav",1.2,0),("0290.wav",1.9,0),("0290.wav",2.9,0)],
    "kart": [("0281.wav",1.0,-.15),("0281.wav",1.6,-.15),("0281.wav",2.25,-.15)],
}
from compact_audio_mastering import render as render_compact
render_compact(read, steady, filter_audio, transpose, write)
if args.compact_only:
    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    replaced = {item["file"] for item in outputs}
    manifest["outputs"] = [next(new for new in outputs if new["file"] == item["file"]) if item["file"] in replaced else item for item in manifest["outputs"]]
    manifest["compact_revision"] = "engine-4-stable-idle"
    (OUT / "manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"compact_clips":len(outputs),"bytes":sum((OUT / item["file"]).stat().st_size for item in outputs)},indent=2))
    raise SystemExit(0)
for car, layers in profiles.items():
    voiced_layers = []
    for index, (source,pitch,warmth) in enumerate(layers):
        values = transpose(filter_audio(steady(read(source)),high=min(9000,19000/pitch)),pitch)
        values = filter_audio(values,low=45 if car in ["formula","kart"] else 35,high=8500,warmth=warmth)
        voiced_layers.append(values)
    anchors = {"pickup":(950,2400,4400),"classic":(1250,3200,6500),"formula":(2100,5800,11000),"kart":(1800,4700,9300)}[car]
    orders = coherent_orders(voiced_layers[1],RATE,anchors)
    for index,values in enumerate(voiced_layers):
        source = layers[index][0]
        sustained, details = engine_sustain(values,RATE,orders[index])
        write(f"{car}_{index}_load",sustained,[source],engine_order=orders[index],loop_ready=True)
        outputs[-1]["cycle_average"] = details
        write(f"{car}_{index}_coast",filter_audio(sustained,high=2800,warmth=.15),[source],rms=.11,engine_order=orders[index],loop_ready=True)
        outputs[-1]["cycle_average"] = details

surface_sources = {
    "road":("Vehicle_Car_Drive_Interior_Loop_Stereo_01.wav",800,6500),
    "loose":("Vehicle_Truck_Drive_Dirty_Ground_Exterior_Loop_Stereo.wav",650,11000),
    "grass":("Vehicle_Truck_Drive_Grass_Exterior_Loop_Stereo.wav",750,8500),
    "tire":("tires_squal_loop.wav",450,8500),
}
for name,(source,low,high) in surface_sources.items():
    write(name,filter_audio(steady(read(source),12.5),low=low,high=high),[source],rms=.11)
# Desert spray is granular ground foley, with the vehicle's low tonal bands removed.
source = "Vehicle_Truck_Drive_Dirty_Ground_Exterior_Loop_Stereo.wav"
write("sand",filter_audio(steady(read(source)),low=1400,high=10500),[source],rms=.10)
for index,number in enumerate(["01","03","05"]):
    source = "Footsteps_Iceland_Run_Black_Pebble_Mono_"+number+".wav"
    grains = filter_audio(read(source),low=380,high=8500)
    peak = int(np.argmax(np.abs(grains)))
    # Short crunchy sprays: strip the footfall's bass and keep the pebble scatter.
    grains = grains[max(0,peak-round(.009*RATE)):peak+round(.18*RATE)]
    write("grit_"+str(index),grains,[source],looping=False,rms=.17)
for index,source in enumerate(["Vehicle_Car_Door_Closing_Exterior_Mono_01.wav","Vehicle_Car_Trunk_Close_Impact_Mono.wav","Vehicle_Car_Door_Closing_Exterior_Mono_02.wav"]):
    values = read(source)
    peak = np.argmax(np.abs(values))
    values = values[max(0,peak-round(.02*RATE)):peak+round(.6*RATE)]
    write("impact_"+str(index),filter_audio(values,high=6200,warmth=.5),[source],looping=False,rms=.23)
source = "Vehicle_Truck_Body_Movement_Interior_Mono_01.wav"
write("chassis",steady(read(source),.32),[source],looping=False,rms=.16)
# Original restrained wind/spray beds supplement recorded mechanical assets.
rng = np.random.default_rng(6102026)
noise = rng.normal(0,.1,RATE*12)
write("wind",filter_audio(noise,low=90,high=1600),[],rms=.07)
write("water",filter_audio(noise,low=500,high=6500),[],rms=.09)
# Continuous wet tire hiss with recorded rolling texture underneath. No rain
# droplets or periodic splash hits; a designed derivative, not a wet field recording.
source = surface_sources["road"][0]
road_texture = filter_audio(steady(read(source),6.0),low=180,high=4200)
road_texture /= max(np.sqrt(np.mean(road_texture**2)),1e-8)
wet_rng = np.random.default_rng(9102026)
spray = filter_audio(wet_rng.normal(0,1,len(road_texture)),low=1100,high=5600)
spray /= max(np.sqrt(np.mean(spray**2)),1e-8)
write("wet_road",road_texture*.55+spray*.45,[source],rms=.13)
from surface_audio_mastering import render
previous_outputs = outputs[:]
outputs.clear()
render(read, steady, filter_audio, transpose, write, RATE)
replaced = {item["file"] for item in outputs}
outputs[:] = [item for item in previous_outputs if item["file"] not in replaced] + outputs
manifest = {"schema":"vehicle-audio-bank-v1","revision":"all-loops-8","compact_revision":"engine-4-stable-idle","rate":RATE,"channels":1,"bits":16,"sources":sources,"outputs":outputs}
(OUT / "manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"clips":len(outputs),"bytes":sum(p.stat().st_size for p in OUT.glob('*.wav')),"maximum_peak_dbfs":max(x['peak_dbfs'] for x in outputs),"maximum_seam_step":max(x['seam_step'] or 0 for x in outputs)},indent=2))
