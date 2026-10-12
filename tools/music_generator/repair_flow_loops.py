"""Preserve first exports; damp32ms around the percussive loop boundary."""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
import soundfile as sf
import render_score_v1 as audio

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'build/music/flow-recompose-2026-10-08'
MASTER=WORK/'loop-repair-v2/masters';EXPORT=WORK/'loop-repair-v2/exports'


def main():
    if (EXPORT/'manifest.json').exists():raise ValueError('Preserve repair exports')
    MASTER.mkdir(parents=True,exist_ok=True);EXPORT.mkdir(parents=True,exist_ok=True)
    audio.MASTERS=MASTER;audio.OUTPUT=EXPORT
    audio.FFMPEG=str(Path.home()/'.local/share/bmt-music-tools/ffmpeg')
    m=json.loads((WORK/'exports/manifest.json').read_text())
    replaced=[]
    for biome in ['pine','desert','winter','night_city','storm']:
        pcm,rate=sf.read(WORK/'masters'/(biome+'_groove.wav'),always_2d=True)
        width=round(rate*.032)
        taper=np.sin(np.linspace(0,np.pi/2,width))**2
        pcm[:width]*=taper[:,None];pcm[-width:]*=taper[::-1,None]
        row=audio.export_loop(biome+'_groove',pcm,'complementary_performance_component')
        assert row['seam_delta']<.001,'Decoded percussive seam must be quiet'
        index=next(i for i,v in enumerate(m['outputs']) if v['file']==row['file'])
        m['outputs'][index]=row;replaced.append(row['file'])
    m['loop_repair']={'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'files':replaced,'change':'32ms boundary damping only on rhythmic component; unchanged exact frame count and other performances',
        'original_exports':'build/music/flow-recompose-2026-10-08/exports'}
    (EXPORT/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
    shutil.copyfile(Path(__file__),MASTER/'repair.py')
    print('FLOW_LOOP_REPAIR',len(replaced),'preserved old exports, no relaxed assertion')


if __name__=='__main__':main()
