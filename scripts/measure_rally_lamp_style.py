"""RLS04: record the appearance tradeoff against the opaque and earlier lamps."""
import json
from run_rally_lamp_style import OUT
old=json.loads((OUT/'before.json').read_text())['rows']
new=json.loads((OUT/'prepared.json').read_text())['rows']
before={(r['vehicle'],r['mode']):r['inventory'] for r in old}
geometry=[]
for row in new:
    if row['vehicle']!='compact':continue
    a=row['inventory'];b=before[(row['vehicle'],row['mode'])]
    geometry.append(dict(mode=row['mode'],triangles_before=b['triangles'],triangles_after=a['triangles'],
        buffer_bytes_before=b['buffer_bytes'],buffer_bytes_after=a['buffer_bytes'],surfaces_before=b['surfaces'],surfaces_after=a['surfaces']))
renderers={}
for renderer in ('gl_compatibility','mobile'):
    day=json.loads((OUT/('prepared-'+renderer)/'comparisons.json').read_text())
    night=json.loads((OUT/('prepared-'+renderer+'-night')/'comparisons.json').read_text())
    assert day['failures']==0 and night['failures']==0
    for row in day['pairs']+night['pairs']:assert row['stable_reference'] and row['restored_exact'],row['label']
    renderers[renderer]=dict(day=day,night=night)
receipt=dict(geometry=geometry,renderers=renderers,earlier_lamp_triangles=1384,opaque_lamp_triangles=960,restored_lamp_triangles=1312,
    retained_grille_triangles=886,stock_restored_baseline=19074,stock_current=16213,
    cumulative_reduction_percent=100*(1-16213/19074),
    tradeoff='Restoring the requested reflector/bulb style adds 352 stock triangles, 9672 encoded mesh bytes and two material surfaces relative to the opaque revision. It remains below the earlier front hardware and about 15% below restored baseline stock geometry. No FPS or device-performance claim.')
(OUT/'measurements.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(dict(geometry=geometry,cumulative_reduction_percent=receipt['cumulative_reduction_percent']),indent=2))
