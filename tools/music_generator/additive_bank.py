"""Author and render R3: exact shared score, six instruments, three alternatives each.

Windows offline tool: Python + numpy + g++ (no runtime/game dependency).
Downloads pinned, licensed renderer assets once into .tools; writes a fresh bank.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import itertools
import json
import shutil
import subprocess
import urllib.request
import uuid
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / '.tools/music-layer-renderer'
TSF = '853a0a171759f1ddba0de1442133a75912bbeffa'
GS = '684543d5e5efaef08d02be50dcda8d552478fa60'
RATE, FRAMES = 48000, 768000
ROLES = [('Acoustic motif', 24, .8), ('Finger bass', 33, .85),
         ('Warm piano', 0, .45), ('Acoustic drums', 0, .65),
         ('Muted guitar', 28, .5), ('Organ answer', 16, .32)]
# Two bars each: D minor, B flat, F major, C major. All variants use these exact voicings.
CHORDS = [(62, 65, 69), (58, 62, 65), (60, 65, 69), (60, 64, 67)]

def notes(role, variant):
    events = []
    def add(beat, duration, key, velocity):
        events.append([round(beat, 4), round(duration, 4), key, round(velocity, 4)])
    for bar in range(8):
        chord = CHORDS[bar // 2]
        start = bar * 4
        # Foreground motif occupies beats 0..2; organ responds only in beats 2.5..4.
        if role == 0:
            rhythms = [(0, .75, 1.5), (0, 1, 1.75), (.25, .75, 1.5)][variant]
            contour = [(0, 2, 1), (2, 1, 0), (1, 2, 0)][(bar + variant) % 3]
            for i, beat in enumerate(rhythms):
                add(start + beat, min(.48, 2.15 - beat), chord[contour[i]] + 12, .62 + .07 * (i == 0))
        elif role == 1:
            root = [38, 34, 41, 36][bar // 2]
            for beat, key in [(0, root), (2, root + (7 if variant == 1 else 0))]:
                add(start + beat, 1.55 if variant == 0 else 1.2, key, .7)
            if variant == 2:
                add(start + 3.5, .32, root + 12, .5)
        elif role == 2:
            for beat in ([.5, 2.5], [1, 3], [.75, 2.75])[variant]:
                for i, key in enumerate(chord):
                    add(start + beat + i * .025, .7, key, .4 + .035 * ((bar + i) % 3))
        elif role == 3:
            for beat in (0, 2, *([2.75] if variant == 1 else []), *([3.5] if variant == 2 else [])):
                add(start + beat, .12, 36, .72)
            for beat in (1, 3):
                add(start + beat, .1, 38 if variant != 0 else 37, .57)
            for i in range(8):
                add(start + i * .5, .09, 42, .36 if i % 2 else .47)
            if bar == 7 and variant == 2:
                add(start + 3.75, .1, 45, .45)
        elif role == 4:
            for i, beat in enumerate(([.5, 1.5, 2.5, 3.5], [0, 1.5, 2, 3.5], [.75, 1.75, 2.75])[variant]):
                add(start + beat, .18, chord[(i + variant) % 3], .52 + .04 * (bar % 2))
        else:
            for i, beat in enumerate(([2.5, 3.25], [2.75, 3.5], [2.5, 3, 3.5])[variant]):
                add(start + beat, .38, chord[(2 - i + variant) % 3] + 12, .44)
    return sorted(events)

def validate_score():
    for role, variant in itertools.product(range(6), range(3)):
        score = notes(role, variant)
        assert score and all(0 <= b < b+d <= 32 and 0 < v <= 1 for b,d,k,v in score)
        if role != 3:
            for b,d,key,v in score:
                allowed = {k % 12 for k in CHORDS[int(b // 8)]}
                assert key % 12 in allowed, (role, variant, b, key)
                assert int(b // 8) == int((b+d-1e-6) // 8), 'note crosses harmony change'
        assert len({json.dumps(notes(role, v)) for v in range(3)}) == 3
    # Every combination observes harmonic and foreground constraints by construction.
    for motif, answer in itertools.product(range(3), repeat=2):
        assert all(a+d <= b or b+e <= a for a,d,_,_ in notes(0,motif) for b,e,_,_ in notes(5,answer))

def main():
    validate_score()
    TOOL.mkdir(parents=True, exist_ok=True)
    inputs = []
    for repo, commit, src, dst in [
        ('schellingb/TinySoundFont', TSF, 'tsf.h', 'tsf.h'),
        ('schellingb/TinySoundFont', TSF, 'LICENSE', 'TinySoundFont.LICENSE'),
        ('mrbumpy409/GeneralUser-GS', GS, 'GeneralUser-GS.sf2', 'GeneralUser-GS.sf2'),
        ('mrbumpy409/GeneralUser-GS', GS, 'documentation/LICENSE.txt', 'GeneralUser.LICENSE')]:
        url = f'https://raw.githubusercontent.com/{repo}/{commit}/{src}'
        target = TOOL / dst
        if not target.exists():
            target.write_bytes(urllib.request.urlopen(url, timeout=120).read())
        inputs.append({'path_or_uri': url, 'local': str(target.relative_to(ROOT)),
                       'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    compiler = shutil.which('g++') or 'C:/msys64/mingw64/bin/g++.exe'
    renderer = TOOL / 'render_score.exe'
    subprocess.run([compiler, '-O2', '-std=c++17', '-static', '-I', str(TOOL),
                    str(Path(__file__).with_name('render_score.cpp')), '-o', str(renderer)], check=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')
    out = ROOT / 'build/music/additive' / f'shared-road-r3-{stamp}-{uuid.uuid4().hex[:6]}'
    out.mkdir(parents=True)
    audio, jobs = [], []
    for role, (name, program, gain) in enumerate(ROLES):
        alternatives = []
        for variant in range(3):
            stem = f'{role+1:02}-{name.lower().replace(" ", "-")}-{variant+1}'
            score = notes(role, variant)
            (out / f'{stem}.score').write_text('\n'.join(' '.join(map(str,e)) for e in score))
            subprocess.run([str(renderer), str(TOOL/'GeneralUser-GS.sf2'), str(out/f'{stem}.score'),
                            '128' if role == 3 else '0', str(program), str(out/f'{stem}.f32')], check=True)
            samples = np.fromfile(out/f'{stem}.f32', dtype='<f4').reshape(FRAMES,2) * gain
            assert np.isfinite(samples).all() and np.max(np.abs(samples)) > .001
            alternatives.append(samples)
            jobs.append({'status':'complete', 'name':f'{name} · {"ABC"[variant]}', 'file':f'{stem}.wav',
                         'family':'shared_road_r3', 'kind':'isolated instrument', 'state_index':role,
                         'variant':variant+1, 'alignment':'120 BPM · Dm / Bb / F / C · 8 bars · shared sample clock',
                         'prompt':'Original scored part; sampled GeneralUser GS instrument, no artist audio.',
                         'score':f'{stem}.score', 'program':program, 'bank':128 if role==3 else 0})
        audio.append(np.stack(alternatives))
        print(name, 'rendered', flush=True)
    # A sample-wise interval bound covers ALL 729 choices, every stage prefix and
    # arbitrary muted subsets. One common gain preserves instrumental balance.
    upper = sum(np.maximum(0, a.max(axis=0)) for a in audio)
    lower = sum(np.minimum(0, a.min(axis=0)) for a in audio)
    bound = float(max(upper.max(), -lower.min()))
    common_gain = .68 / bound
    hashes = []
    for index, job in enumerate(jobs):
        samples = audio[index//3][index%3] * common_gain
        pcm = np.rint(samples * 32767).astype('<i2')
        with wave.open(str(out/job['file']), 'wb') as wav:
            wav.setnchannels(2); wav.setsampwidth(2); wav.setframerate(RATE); wav.writeframes(pcm.tobytes())
        job['sha256'] = hashlib.sha256((out/job['file']).read_bytes()).hexdigest()
        hashes.append(job['sha256'])
        job['metrics'] = {'duration':16, 'frames':FRAMES, 'sample_rate':RATE, 'channels':2,
                          'peak':float(np.max(np.abs(samples))),
                          'loop_boundary_delta':float(np.max(np.abs(samples[0]-samples[-1])))}
    assert len(set(hashes)) == 18
    manifest = {'schema_version':1, 'approval':'unreviewed', 'asset_id':out.name,
                'source_type':'rendered', 'generator':{'tool':'TinySoundFont', 'tool_version':TSF,
                'command_or_entrypoint':'python tools/music_generator/additive_bank.py'},
                'input_sources':inputs, 'score_contract':{'bpm':120,'bars':8,'beats':32,
                'progression':['Dm','Bb','F','C'],'variants_per_role':3,'combinations':729},
                'mix':{'common_gain':common_gain,'all_subsets_sample_peak_bound':.68 + 6/32767,
                       'normalization':'one shared gain, no per-stem normalization'},
                'licensing':{'renderer':'MIT','samples':'GeneralUser GS 2.0.3 License 2.0 permits music creation; upstream discloses incomplete historical sample provenance.',
                'commercial_use_status':'audition only; shipping provenance review and user approval pending'},
                'tests':{'score_harmony_and_foreground':'PASS','all_18_finite_nonzero_unique':'PASS',
                         'all_729_choices_and_muted_subsets_peak_bound':'PASS'}, 'jobs':jobs}
    for license_name in ('TinySoundFont.LICENSE','GeneralUser.LICENSE'):
        shutil.copyfile(TOOL/license_name, out/license_name)
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    evidence = ROOT/'docs/evidence/music-r3'
    evidence.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(out/'manifest.json',evidence/'generation-manifest.json')
    for license_name in ('TinySoundFont.LICENSE','GeneralUser.LICENSE'):
        shutil.copyfile(out/license_name,evidence/license_name)
    print(out)

if __name__ == '__main__':
    main()
