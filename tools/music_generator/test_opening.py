"""Verify R5's actual note lengths/register, audibility and unchanged backing score."""
import hashlib
import json
import wave
import numpy as np
from additive_bank import ROOT, RATE, CHORDS
from refine_opening import read_audio
from serve import catalog

OUT=ROOT/'docs/evidence/music-r5'
results=[]
for category in ['additive','tempo']:
    m=json.loads((OUT/(category+'-manifest.json')).read_text(encoding='utf-8'))
    folder=ROOT/'build/music'/category/m['asset_id']
    old_path=ROOT/m['revised_from'];old=json.loads(old_path.read_text(encoding='utf-8'))
    leads=[]
    for j in m['jobs']:
        a=read_audio(folder/j['file'])
        assert np.isfinite(a).all() and np.sqrt(np.mean(a*a))>.0001
        bpm=j.get('bpm',120)
        assert len(a)==round(32*60/bpm*RATE)
        assert np.max(np.abs(a[0]-a[-1]))<.002
        score=np.loadtxt(folder/j['score'])
        if j['state_index']==0:
            assert j['program']==42 and len(score)==4
            assert score[:,2].min()>=50 and score[:,2].max()<=57
            assert np.min(score[:,1])*60/bpm>=2.72-1e-6
            for beat,duration,key,velocity in score:
                assert int(key)%12 in {k%12 for k in CHORDS[int(beat//8)]}
                assert beat+duration<(int(beat//8)+1)*8
            assert np.sqrt(np.mean(a*a))>.005, 'replacement must remain audible'
            spectrum=np.abs(np.fft.rfft(a,axis=0))**2
            high=float(spectrum[np.fft.rfftfreq(len(a),1/RATE)>2000].sum()/spectrum.sum())
            assert high<.03, 'high-frequency energy must be restrained'
            leads.append({'bpm':bpm,'variant':j['variant'],'rms':float(np.sqrt(np.mean(a*a))),'energy_above_2khz':high})
        else:
            prior=next(x for x in old['jobs'] if x['state_index']==j['state_index'] and x['variant']==j['variant'] and x.get('bpm',120)==bpm)
            assert (folder/j['score']).read_bytes()==(old_path.parent/prior['score']).read_bytes()
            expected=np.rint(read_audio(old_path.parent/prior['file'])*.85*32767).astype('<i2')
            assert np.array_equal(np.rint(a*32768).astype('<i2'),expected)
    assert m['mix']['all_subsets_sample_peak_bound']<.681
    results.append({'bank':m['asset_id'],'openings':leads})
items=catalog()['items']
assert not any(i.get('state_index')==0 and i.get('program')==24 and i.get('family') in ('shared_road_r3','evolving_r4') for i in items)
(OUT/'opening-results.json').write_text(json.dumps({'result':'PASS','checks':['four low sustained notes per phrase','D3-A3 range',
    'at least 2.72 seconds gate at fastest tempo','chord-tone alignment','audible replacement RMS','less than 3 percent spectral energy above 2 kHz',
    'unchanged backing scores and shared 0.85 backing gain','finite exact-length loops','rejected acoustic excluded from catalog'], 'results':results},indent=2))
print('PASS: revised opening (9 grouped checks)')
