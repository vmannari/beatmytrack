"""CP203: source/prepared geometry and native viewport measurements."""
import json
from run_car_pass12 import OUT
before=json.loads((OUT/'before.json').read_text())
after=json.loads((OUT/'prepared-models.json').read_text())
assert before['failures']==after['failures']==0
old={(r['vehicle'],r['mode']):r['inventory'] for r in before['rows']}
rows=[]
for r in after['rows']:
    b=old[r['vehicle'],r['mode']];a=r['inventory']
    rows.append(dict(vehicle=r['vehicle'],mode=r['mode'],**{key+'_'+when:value[key] for key in ('triangles','buffer_bytes','surfaces') for when,value in [('before',b),('after',a)]}))
renders={}
for method in ('gl_compatibility','mobile'):
    capture=json.loads((OUT/('prepared-'+method+'-decorated/comparisons.json')).read_text())
    assert capture['failures']==0
    assert all(r['stable_reference'] and r['restored_exact'] for r in capture['pairs'])
    renders[method]=capture
totals={key:sum(r[key] for r in rows if r['mode']=='stock') for key in ('triangles_before','triangles_after','buffer_bytes_before','buffer_bytes_after')}
totals['triangle_reduction_percent']=100*(1-totals['triangles_after']/totals['triangles_before'])
totals['buffer_reduction_percent']=100*(1-totals['buffer_bytes_after']/totals['buffer_bytes_before'])
(OUT/'measurements.json').write_text(json.dumps(dict(geometry=rows,totals=totals,renderers=renders,limits='Desktop encoded mesh buffers and viewport counters. No paired FPS, GPU-time or phone-performance measurement.'),indent=2)+'\n')
print(json.dumps(totals))
