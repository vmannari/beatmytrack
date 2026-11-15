"""RFL04: measured master, buffer, surface and matched viewport costs."""
import json
from run_rally_front import OUT
old=json.loads((OUT/'before.json').read_text())['rows']
new=json.loads((OUT/'prepared.json').read_text())['rows']
before={(r['vehicle'],r['mode']):r['inventory'] for r in old}
geometry=[]
for r in new:
    if r['vehicle']!='compact':continue
    a=r['inventory'];b=before[(r['vehicle'],r['mode'])]
    geometry.append(dict(mode=r['mode'],triangles_before=b['triangles'],triangles_after=a['triangles'],
        buffer_bytes_before=b['buffer_bytes'],buffer_bytes_after=a['buffer_bytes'],
        surfaces_before=b['surfaces'],surfaces_after=a['surfaces']))
renderers={}
for renderer in ('gl_compatibility','mobile'):
    day=json.loads((OUT/('prepared-'+renderer)/'comparisons.json').read_text())
    night=json.loads((OUT/('prepared-'+renderer+'-night')/'comparisons.json').read_text())
    assert day['failures']==0 and night['failures']==0
    for p in day['pairs']+night['pairs']:assert p['stable_reference'] and p['restored_exact'],p['label']
    renderers[renderer]=dict(day_checks=day['checks'],day_pairs=len(day['pairs']),night_checks=night['checks'],night_pairs=len(night['pairs']),
        day=day['pairs'],night=night['pairs'])
scope=dict(racing_grille_before=1254,racing_grille_after=886,racing_lamps_before=1384,racing_lamps_after=960,
           racing_front_before=2638,racing_front_after=1846,full_front_before=4726,full_front_after=2086)
scope['racing_front_reduction_percent']=100*(1-scope['racing_front_after']/scope['racing_front_before'])
receipt=dict(scope=scope,geometry=geometry,renderers=renderers,
    limits='Matched desktop viewport primitives/draw calls and encoded mesh buffers, with exact baseline restoration controls. No FPS/GPU timing or device-performance qualification. Existing 176px icon LOD selection can draw slightly more primitives for the smoother authored profiles.')
(OUT/'measurements.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(dict(scope=scope,geometry=geometry),indent=2))
