"""Beat My Track 'locks in': one four-note identity, five band palettes, exact layers.

Recorded guitar/bass/acoustic kit, handwritten cells and fixed performance nuance.
No AI generation or realtime synthesis. New immutable master/export directories.
"""
from __future__ import annotations
from pathlib import Path
from functools import lru_cache
import argparse
import hashlib
import json
import math
import re
import shutil
import sys
import scipy

import numpy as np
from scipy.signal import butter, resample_poly, sosfilt
import soundfile as sf
import render_score_v1 as chamber

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "build/music/locked-in-v1/sources"
MASTERS = ROOT / "build/music/locked-in-v1/masters"
EXPORT = ROOT / "build/music/locked-in-v1/exports"
EVIDENCE = ROOT / "docs/evidence/locked-in-score-2026-10-07"
RATE, BPM, FRAMES = 44100, 144, 2352000
MOTIF = [62, 64, 69, 66]  # D, E, A, F#: anticipation, reach and return.
LAYERS = ["pulse", "lock", "groove", "hook", "wide", "soar"]
BIOMES = ["pine", "desert", "winter", "night_city", "storm"]
SOURCE_MANIFEST = json.loads((SOURCE / "manifest.json").read_text())
SOURCES = {row["path"]: row for row in SOURCE_MANIFEST["sources"] if row["role"] != "licence"}
POOLS = {kind: [path for path, row in SOURCES.items() if row["role"] == kind]
         for kind in ["guitar", "bass", "kick", "snare", "snare_room", "hat", "hat_open", "tom", "ride", "crash"]}


def note_number(path):
    match = re.search(r"_([a-g])(b?)(\d)_", Path(path).name)
    value = chamber.midi(match[1].upper() + match[2] + match[3])
    # Measured sounding fundamentals are an octave below both filename registers.
    # Bass SFZ declares the keyboard register separately; here score pitches are sounding pitches.
    return value - 12


@lru_cache(maxsize=160)
def source_audio(path):
    data = (SOURCE / path).read_bytes()
    assert hashlib.sha256(data).hexdigest() == SOURCES[path]["sha256"]
    pcm, rate = sf.read(SOURCE / path, always_2d=True)
    if rate != RATE:
        d = math.gcd(rate, RATE)
        pcm = resample_poly(pcm, RATE // d, rate // d, axis=0)
    if pcm.shape[1] == 1: pcm = np.repeat(pcm, 2, axis=1)
    pcm = pcm[:, :2]
    assert np.isfinite(pcm).all() and len(pcm) > 100
    onset = np.argmax(np.max(np.abs(pcm), axis=1) > np.max(np.abs(pcm)) * .009)
    pcm = pcm[max(0, onset - 220):]
    pcm -= pcm.mean(axis=0)
    rms = np.sqrt(np.mean(pcm[:min(len(pcm), RATE)] ** 2))
    ceiling = 20.0 if path.startswith("guitar/") else 5.0
    floor = .002 if path.startswith("guitar/") else .008
    return pcm * min(ceiling, .12 / max(rms, floor))


@lru_cache(maxsize=600)
def performed(kind, pitch, frames, variant, strong):
    if kind in ["piano", "cello", "violin"]:
        return chamber.performed(kind, pitch, frames, variant % 2)
    pool = POOLS[kind]
    if kind in ["guitar", "bass"]:
        nearest = min(abs(note_number(p) - pitch) for p in pool)
        matches = [p for p in pool if abs(note_number(p) - pitch) == nearest]
        velocity = "mf" if strong else ("p" if kind == "guitar" else "mp")
        matches = [p for p in matches if f"_{velocity}_" in p]
        path = matches[variant % len(matches)]
        ratio = 2 ** ((pitch - note_number(path)) / 12)
    else:
        # Recorded velocity/RR changes, rather than repeatedly hitting one sample.
        levels = sorted(set(int(re.search(r'_vl(\d+)_', p)[1]) for p in pool))
        level = levels[-1] if strong else levels[0]
        matches = [p for p in pool if f"_vl{level}_" in p]
        path = matches[variant % len(matches)]
        ratio = 1.0
    pcm = source_audio(path)
    if ratio != 1.0:
        den, num = 4096, round(4096 / ratio)
        d = math.gcd(den, num)
        pcm = resample_poly(pcm, num // d, den // d, axis=0)
    release = round(RATE * (.3 if kind == "bass" else .65))
    count = frames + release
    pcm = np.pad(pcm[:count], ((0, max(0, count - len(pcm))), (0, 0)))
    attack = min(220, len(pcm))
    pcm[:attack] *= np.linspace(0, 1, attack)[:, None]
    pcm[-release:] *= np.cos(np.linspace(0, np.pi / 2, release))[:, None] ** 2
    return pcm


class Cells:
    def __init__(self, biome="pine", bpm=BPM, bars=32):
        self.biome, self.bpm = biome, bpm
        self.frames = round(bars * 4 * RATE * 60 / bpm)
        self.parts = [np.zeros((self.frames, 2)) for _ in LAYERS]
        self.events = []

    def hit(self, layer, kind, pitch, beat, duration, gain, pan=0, strong=False):
        index = len(self.events)
        precision = .002 if self.biome == "night_city" else .008
        timing = math.sin(index * 1.71) * precision
        # Backbeat sits just behind the bass; fills vary while retaining shared bars.
        if kind in ["snare", "snare_room"]: timing += .008 if self.biome != "night_city" else .002
        start = round((beat * 60 / self.bpm + timing) * RATE) % self.frames
        sample = performed(kind, pitch, round(duration * 60 / self.bpm * RATE), index % 4, strong)
        sample = sample * gain * (1 + .06 * math.sin(index * .73))
        sample = sample * np.array([math.sqrt((1 - pan) / 2), math.sqrt((1 + pan) / 2)])
        first = min(len(sample), self.frames - start)
        self.parts[layer][start:start + first] += sample[:first]
        if first < len(sample): self.parts[layer][:len(sample) - first] += sample[first:]
        self.events.append({"layer": LAYERS[layer], "instrument": kind, "midi": pitch,
                            "beat": beat, "length": duration, "gain": gain, "timing_offset": timing})


HARMONY = [(38, [50, 57, 66]), (43, [55, 59, 62]), (38, [54, 57, 62]), (45, [52, 57, 61])]


def compose(biome):
    score = Cells(biome)
    for bar in range(32):
        at = bar * 4
        root, chord = HARMONY[bar % 4]
        # Fragmented pulse: two bass gestures, small tactile time and partial identity.
        score.hit(0, "bass", root, at, .9, .42)
        score.hit(0, "bass", root + 7, at + 2.5, .6, .26)
        score.hit(0, "hat", 60, at + 1, .2, .085, .08)
        score.hit(0, "hat", 60, at + 3, .2, .065, .08)
        if bar % 4 == 0:
            kind = "piano" if biome == "winter" else "guitar"
            score.hit(0, kind, MOTIF[0] - 12, at + .25, .75, .20, -.12)
            score.hit(0, kind, MOTIF[1] - 12, at + 1.5, .7, .14, -.12)
        # Coherent: the missing bass notes/guitar voicing fit into the existing holes.
        for beat, pitch in [(.75, root + 2), (1.75, root + 7), (3.25, root + 4)]:
            score.hit(1, "bass", pitch, at + beat, .55, .24)
        for beat in [.5, 2.75]:
            for n, pitch in enumerate(chord):
                score.hit(1, "guitar", pitch, at + beat + .028 * n, 1.1, .14, -.22)
        # Played kit: close and room recordings, softer ghost hits, rotating fills.
        for beat, gain in [(0,.35),(1.75,.23),(2.5,.29)]: score.hit(2,"kick",60,at+beat,.35,gain,0,True)
        for beat in [1, 3]:
            score.hit(2,"snare",60,at+beat,.45,.30,-.04,True)
            score.hit(2,"snare_room",60,at+beat,.65,.10,.08,True)
        if bar % 2 == 1: score.hit(2,"snare",60,at+2.75,.25,.06,-.04)
        for eighth in range(8):
            if bar % 4 == 3 and eighth == 7: continue
            score.hit(2,"hat",60,at+eighth*.5,.2,.14 if eighth%2==0 else .085,.10,eighth%2==0)
        if bar % 4 == 3:
            for n, beat in enumerate([3.25,3.5,3.75]): score.hit(2,"tom",60,at+beat,.35,.12+.035*n,.16)
        if bar % 8 == 0: score.hit(2,"crash",60,at,.9,.13,.2)
        # Recognizable hook: the same four notes and rhythmic gesture every palette.
        if bar % 2 == 0:
            lead = "piano" if biome == "winter" else "guitar"
            for beat, pitch, length in zip([0,.75,2,3], MOTIF, [.65,.85,.8,.9]):
                score.hit(3,lead,pitch,at+beat,length,.32,-.08,lead=="guitar")
        else:
            for beat,pitch in [(1.5,MOTIF[3]),(3,MOTIF[1])]: score.hit(3,"guitar",pitch,at+beat,.8,.20,.12,True)
        # Width/counterpoint grows from known material; keep high-state breathing space.
        for side in [-1, 1]:
            for beat in [.25,2.25]:
                for n,pitch in enumerate(chord): score.hit(4,"guitar",pitch,at+beat+n*.022,1.65,.14,side*.74,True)
        if bar % 4 == 2:
            score.hit(4,"guitar",MOTIF[2],at+1.25,1.0,.20,.38)
            score.hit(4,"piano",MOTIF[3],at+3,1.0,.11,-.25)
        # Only exceptional flow unlocks this octave expansion/soaring held resolution.
        if bar % 4 in [0,2]:
            for beat,pitch in zip([0,.75,2,3],MOTIF): score.hit(5,"guitar",pitch+12,at+beat,1.1,.27,.16,True)
            score.hit(5,"violin",MOTIF[3]+12,at+3.25,3.6,.10,-.14)
        if bar % 8 == 7: score.hit(5,"ride",60,at+3,.7,.12,.2)
    return score


def palette(pcm, layer, biome):
    # Baked instrument processing, never tied to car velocity or display rate.
    pcm = sosfilt(butter(2, 38, "highpass", fs=RATE, output="sos"), np.tile(pcm,(2,1)),axis=0)[len(pcm):]
    cutoff = 4500 if biome == "night_city" else 8000
    pcm = sosfilt(butter(2, cutoff, "lowpass", fs=RATE, output="sos"), np.tile(pcm,(2,1)),axis=0)[len(pcm):]
    if biome == "storm" and layer in [1,4]: pcm = np.tanh(pcm*2.2)/1.8
    if biome == "desert" and layer in [1,4]:
        tremolo = .87 + .13*np.sin(np.arange(len(pcm))/RATE*2*np.pi*(BPM/60.0*2.0))
        pcm *= tremolo[:,None]
    if biome == "winter" and layer in [1,4]:
        pcm = sosfilt(butter(2, 270, "highpass", fs=RATE, output="sos"),np.tile(pcm,(2,1)),axis=0)[len(pcm):]
    wet = np.zeros_like(pcm)
    decay = 5 if biome in ["desert","night_city"] else 11 if biome == "winter" else 7
    for i in range(20):
        delay = round(RATE*(.028+i*.049))
        wet += np.roll(pcm[:,::-1] if i%2 else pcm,delay,axis=0)*.025*math.exp(-i/decay)
    return pcm + wet


def foley(score, biome):
    manifest = json.loads((ROOT/"game/assets/audio/vehicles/manifest.json").read_text())
    clip = next(x for x in manifest["outputs"] if x["file"] == "grit_0.wav")
    path=ROOT/"game/assets/audio/vehicles/grit_0.wav"
    assert hashlib.sha256(path.read_bytes()).hexdigest()==clip["sha256"]
    pcm,rate=sf.read(path,always_2d=True)
    if rate != RATE: pcm=resample_poly(pcm,RATE,rate,axis=0)
    pcm=sosfilt(butter(2,[900,3900],"bandpass",fs=RATE,output="sos"),pcm,axis=0)
    pcm=np.repeat(pcm,2,axis=1) if pcm.shape[1]==1 else pcm
    for bar in range(32):
        if biome=="desert" or bar%4==3:
            start=round((bar*4+3.5)*RATE*60/BPM); count=min(len(pcm),score.frames-start)
            score.parts[0][start:start+count]+=pcm[:count]*.018
    if biome == "storm":
        wind = next(x for x in manifest["outputs"] if x["file"] == "wind.wav")
        wind_path = ROOT / "game/assets/audio/vehicles/wind.wav"
        assert hashlib.sha256(wind_path.read_bytes()).hexdigest() == wind["sha256"]
        raw, wind_rate = sf.read(wind_path, always_2d=True)
        if wind_rate != RATE: raw = resample_poly(raw, RATE, wind_rate, axis=0)
        raw = np.repeat(raw, 2, axis=1) if raw.shape[1] == 1 else raw
        rain = sosfilt(butter(2, [700, 5200], "bandpass", fs=RATE, output="sos"), raw, axis=0)[:RATE // 3]
        rain *= np.sin(np.linspace(0, np.pi, len(rain)))[:, None] ** 2
        for bar in range(32):
            for beat in [1.5, 3.5]:
                start = round((bar * 4 + beat) * RATE * 60 / BPM)
                count = min(len(rain), score.frames - start)
                score.parts[2][start:start + count] += rain[:count] * .05
        score.parts[2] *= 1.10
    return {"path_or_uri":str(path.relative_to(ROOT)),"sha256":clip["sha256"],"role":"quiet filtered gravel percussion","licence":"CC0-1.0 / Nox Sound Design"}


def menu():
    score=Cells("pine",bpm=112,bars=16)
    for bar in range(16):
        root,chord=HARMONY[bar%4]; at=bar*4
        score.hit(0,"bass",root,at,1.4,.16)
        for beat,pitch in zip([0,.75,2,3],MOTIF):
            if bar%2==0: score.hit(0,"guitar",pitch-12,at+beat,1.0,.26,-.12)
        if bar%2:
            for n,pitch in enumerate(chord): score.hit(0,"guitar",pitch,at+.5+n*.028,2.4,.095,.2)
        score.hit(0,"hat",60,at+1,.25,.04,.12)
        score.hit(0,"hat",60,at+3,.25,.035,.12)
    return palette(score.parts[0],0,"pine")


def sting(pb=False, breath=False):
    score=Cells("pine",bpm=BPM,bars=2)
    if breath:
        score.hit(0,"guitar",62,0,2.0,.11)
        return score.parts[0][:round(RATE*1.25)]
    pitches=MOTIF+[74 if pb else 62]
    for n,pitch in enumerate(pitches): score.hit(0,"guitar",pitch,.5*n,.7,.30 if pb else .19,-.1)
    for n,pitch in enumerate([50,57,66]): score.hit(0,"guitar",pitch,2+n*.035,2.2,.18 if pb else .10,.18)
    if pb:
        score.hit(0,"crash",60,2,.8,.12,.22)
        score.hit(0,"piano",74,2,2.0,.16,-.2)
    pcm=palette(score.parts[0],0,"pine")
    pcm[-round(RATE*.5):]*=np.linspace(1,0,round(RATE*.5))[:,None]**2
    pcm[:220]*=np.linspace(0,1,220)[:,None]
    return pcm


def inspect():
    for kind,pitch in [("guitar",50),("guitar",62),("bass",38)]:
        pcm=performed(kind,pitch,RATE*2,0,False).mean(axis=1)
        segment=pcm[RATE//4:RATE]; spectrum=np.abs(np.fft.rfft(segment*np.hanning(len(segment))))
        indices=np.argpartition(spectrum,-4)[-4:]; frequencies=np.fft.rfftfreq(len(segment),1/RATE)
        print(kind,pitch,"expected",440*2**((pitch-69)/12),"peaks",[round(float(frequencies[i]),1) for i in sorted(indices,key=lambda i:-spectrum[i])])


def render():
    if MASTERS.exists() and (MASTERS/"manifest.json").exists(): raise ValueError("Preserve existing render; use a fresh revision directory")
    MASTERS.mkdir(parents=True,exist_ok=True); EXPORT.mkdir(parents=True,exist_ok=True); EVIDENCE.mkdir(parents=True,exist_ok=True)
    chamber.MASTERS=MASTERS; chamber.OUTPUT=EXPORT
    outputs=[]; packages=[]; foley_sources=[]
    for biome in BIOMES:
        score=compose(biome); foley_sources.append(foley(score,biome))
        parts=[palette(part,i,biome) for i,part in enumerate(score.parts)]
        full=sum(parts); gain=min(.48/np.max(np.abs(full)),.060/max(np.sqrt(np.mean(full**2)),1e-9))
        for name,part in zip(LAYERS,parts): outputs.append(chamber.export_loop(f"{biome}_{name}",part,"additive_runtime_layer",gain))
        chamber.write_wav(EVIDENCE/f"{biome}-full.wav",full*gain)
        frames=RATE*90; t=np.arange(frames,dtype=float)/RATE; mix=np.zeros((frames,2))
        for i,part in enumerate(parts):
            entry=[0,6,16,30,44,56][i]; blend=np.clip((t-entry)/4,0,1); blend=blend**2*(3-2*blend)
            if i==0:blend=np.ones(frames)
            mix+=np.tile(part,(2,1))[:frames]*(blend*gain)[:,None]
        mix[:RATE//2]*=np.linspace(0,1,RATE//2)[:,None];mix[-RATE:]*=np.linspace(1,0,RATE)[:,None]
        chamber.write_wav(EVIDENCE/f"{biome}-clean-story.wav",mix)
        packages.append({"id":biome,"bpm":BPM,"bars":32,"frames":FRAMES,"motif":MOTIF,"layers":[f"{biome}_{n}.ogg" for n in LAYERS],"common_gain":float(gain),"combined":chamber.metrics(full*gain),"events":score.events})
        print("FAMILY_COMPLETE",biome,flush=True)
    pcm=menu();gain=min(.30/np.max(np.abs(pcm)),.032/max(np.sqrt(np.mean(pcm**2)),1e-9))
    outputs.append(chamber.export_loop("menu_theme",pcm,"complete_menu_mix",gain)); chamber.write_wav(EVIDENCE/"menu-theme.wav",pcm*gain)
    for name,pb,breath in [("finish",False,False),("personal_best",True,False),("breath",False,True)]:
        pcm=sting(pb,breath);pcm*=min(1.0,.26/max(np.max(np.abs(pcm)),1e-9))
        destination=EXPORT/(name+".wav"); sf.write(destination,pcm,RATE,subtype="PCM_16")
        chamber.write_wav(EVIDENCE/(name+".wav"),pcm)
        outputs.append({"file":destination.name,"role":"musical_event","loop":False,"sha256":hashlib.sha256(destination.read_bytes()).hexdigest(),"bytes":destination.stat().st_size,"duration_seconds":len(pcm)/RATE,"peak_dbfs":chamber.metrics(pcm)["peak_dbfs"]})
    for name in ["ui_select.wav","ui_confirm.wav","ui_back.wav"]:
        source=ROOT/"game/assets/audio/score_v1"/name; dest=EXPORT/name;shutil.copyfile(source,dest)
        outputs.append({"file":name,"role":"interface","loop":False,"sha256":hashlib.sha256(dest.read_bytes()).hexdigest(),"bytes":dest.stat().st_size})
    manifest={"schema_version":1,"asset_id":"bmt-locked-in-band-v1","created_on":"2026-10-07","status":"owner_audition","direction":"fragmented-coherent-driving-euphoric","motif_midi":MOTIF,
        "generator":{"tool":"original written band cells / offline sample performance","python":sys.version.split()[0],"numpy":np.__version__,"scipy":scipy.__version__,"soundfile":sf.__version__,"model":None},
        "score_source_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),"input_sources":SOURCE_MANIFEST,"supporting_sources":{"chamber":chamber.SOURCE_MANIFEST,"foley":foley_sources},
        "packages":packages,"outputs":outputs,"approval":{"user_approved":False,"scope":[]},"licensing":{"recorded_band":"Karoryfer CC0-1.0","chamber":"VSCO 2 CE CC0-1.0","foley":"Nox Sound Design CC0-1.0","commercial_use_status":"cleared recorded sources; original composition"}}
    text=json.dumps(manifest,indent=2)+'\n'; (EXPORT/"manifest.json").write_text(text);(MASTERS/"manifest.json").write_text(text)
    (EXPORT/"NOTICE.txt").write_text("Beat My Track - The music locks in with you, original band score v1.\nRecorded guitar/bass/drums: Karoryfer Samples, sfzinstruments, CC0-1.0.\nPiano/strings: VSCO 2 CE, Sam Gossner/Versilian Studios, Simon Dalzell/Ivy Audio; Elan Hickler/Soundemote. CC0-1.0.\nQuiet gravel percussion: Nox Sound Design, CC0-1.0, derived from the game's cleared grit recording.\nWritten score/performance/processing authored for this project. No reference-game audio or runtime synthesis/API.\nSource URLs, immutable revisions, SHA-256s and export provenance in manifest.json. Musical approval/device listening pending.\n")
    shutil.copyfile(SOURCE/"guitar/LICENSE",EXPORT/"CC0-LICENSE.txt")
    print("LOCKED_IN_RENDER",len(outputs),sum(row["bytes"] for row in outputs),"shipping audio bytes",flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--inspect",action="store_true");parser.add_argument("--mix-revision",type=int,default=1);args=parser.parse_args()
    if args.mix_revision>1:
        MASTERS=ROOT/f"build/music/locked-in-v1/masters-mix{args.mix_revision}"
        EXPORT=ROOT/f"build/music/locked-in-v1/exports-mix{args.mix_revision}"
        EVIDENCE=EVIDENCE/f"mix{args.mix_revision}"
    inspect() if args.inspect else render()
