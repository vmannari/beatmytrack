"""Correlate real-time direct-hit output with physics and rendered footprint."""
from pathlib import Path
import json,subprocess,sys

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/direct-collision-output-2026-10-09'
subprocess.run([sys.executable,str(ROOT/'scripts/review_windows_audio_output.py'),str(OUT)],check=True,capture_output=True)
events=json.loads((OUT/'events.json').read_text())
timings=json.loads((OUT/'timing-report.json').read_text())
rows=[]
checks=0
for event,timing in zip(events,timings['rows']):
    assert event['trial']==timing['trial'];checks+=1
    assert event['route']=='windows_raw' and event['native']['ready'];checks+=1
    assert event['cue_count']==1;checks+=1
    assert event['unix_us']>0 and event['render_contact_us']>0 and event['physical_us']>0;checks+=1
    if event['canonical_only']:
        assert event['cue_tick']==event['physical_tick'];checks+=1
    else:
        assert event['cue_tick']<=event['render_contact_tick']<=event['physical_tick'];checks+=1
    rows.append(dict(trial=event['trial'],speed_mps=event['speed_mps'],canonical_only=event['canonical_only'],
                     route=event['route'],cue_tick=event['cue_tick'],render_contact_tick=event['render_contact_tick'],physical_tick=event['physical_tick'],
                     cue_to_output_ms=timing['latency_ms'],
                     render_contact_to_output_ms=(timing['output_unix_us']-event['render_contact_us'])/1000,
                     physical_contact_to_output_ms=(timing['output_unix_us']-event['physical_us'])/1000))
report=dict(checks=checks,failures=0,rows=rows,
            limits='Own-process software output and frame-post-draw footprint timestamps; excludes monitor scanout and acoustic speaker/headphone latency. canonical_only deliberately disables the early visible-footprint cue as a diagnostic control.')
(OUT/'direct-review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
