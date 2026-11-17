"""CP303: source/prepared geometry and native viewport measurements."""
import json
from run_car_pass10 import OUT
before=json.loads((OUT/'before.json').read_text())
after=json.loads((OUT/'source-models.json').read_text())
prepared=json.loads((OUT/'prepared-models.json').read_text())
assert before['failures']==after['failures']==prepared['failures']==0
packed={(r['vehicle'],r['mode']):r['inventory'] for r in prepared['rows']}
old={(r['vehicle'],r['mode']):r['inventory'] for r in before['rows']}
rows=[]
for r in after['rows']:
    b=old[r['vehicle'],r['mode']];a=r['inventory']
    current=packed[r['vehicle'],r['mode']]
    assert current['triangles']==a['triangles']
    rows.append(dict(vehicle=r['vehicle'],mode=r['mode'],prepared_buffer_bytes_after=current['buffer_bytes'],**{key+'_'+when:value[key] for key in ('triangles','buffer_bytes','surfaces') for when,value in [('before',b),('after',a)]}))
renders={}
for method in ('gl_compatibility','mobile'):
    capture=json.loads((OUT/('prepared-'+method+'-decorated/comparisons.json')).read_text())
    assert capture['failures']==0
    assert all(r['stable_reference'] and r['restored_exact'] for r in capture['pairs'])
    renders[method]=capture
totals={key:sum(r[key] for r in rows if r['mode']=='stock') for key in ('triangles_before','triangles_after','buffer_bytes_before','buffer_bytes_after')}
totals['triangle_reduction_percent']=100*(1-totals['triangles_after']/totals['triangles_before'])
totals['buffer_reduction_percent']=100*(1-totals['buffer_bytes_after']/totals['buffer_bytes_before'])
totals['prepared_buffer_bytes_after']=sum(r['prepared_buffer_bytes_after'] for r in rows if r['mode']=='stock')
(OUT/'measurements.json').write_text(json.dumps(dict(geometry=rows,totals=totals,renderers=renders,limits='Matched source-built before/after buffers include stored LODs. Current prepared buffers are separate; no fresh paired prepared-before payload was captured. Desktop viewport counters establish no FPS, GPU-time or phone-performance gain.'),indent=2)+'\n')
print(json.dumps(totals))
