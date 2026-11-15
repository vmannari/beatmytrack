"""C1504: publish measured geometry/memory and paired native render costs."""
import json
import subprocess
from run_car_step10 import OUT

subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/measure_car_step10_images.ps1'],check=True)
pixels=json.loads((OUT/'image-metrics.json').read_text(encoding='utf-8-sig'))

before=json.loads((OUT/'before.json').read_text())
after=json.loads((OUT/'prepared.json').read_text())
plan=json.loads((OUT/'selected-plan.json').read_text())
old={(r['vehicle'],r['mode']):r['inventory'] for r in before['rows']}
rows=[]
for r in after['rows']:
    b=old[(r['vehicle'],r['mode'])];a=r['inventory']
    if r['vehicle']=='super_rally':continue
    rows.append(dict(vehicle=r['vehicle'],mode=r['mode'],
        triangles_before=b['triangles'],triangles_after=a['triangles'],
        buffer_bytes_before=b['buffer_bytes'],buffer_bytes_after=a['buffer_bytes'],
        surfaces_before=b['surfaces'],surfaces_after=a['surfaces']))
renders={}
for method in ('gl_compatibility','mobile'):
    folder=OUT/('prepared-'+method)
    capture=json.loads((folder/'comparisons.json').read_text())
    assert capture['failures']==0
    pairs=[]
    for row in capture['pairs']:
        assert row['stable_reference'] and row['restored_exact'],row['label']
        pairs.append(dict(row,**pixels[method][row['label']]))
    renders[method]=dict(checks=capture['checks'],failures=capture['failures'],pairs=pairs)
totals={}
for key in ('triangles_before','triangles_after','buffer_bytes_before','buffer_bytes_after'):
    totals[key]=sum(row[key] for row in rows if row['mode']=='stock')
totals['restored_triangles']=sum(row['restored'] for row in plan['rows'])
totals['cumulative_triangle_reduction_percent']=100*(1-totals['triangles_after']/totals['restored_triangles'])
totals['this_step_triangle_reduction_percent']=100*(1-totals['triangles_after']/totals['triangles_before'])
(OUT/'measurements.json').write_text(json.dumps(dict(geometry=rows,totals=totals,renderers=renders,
    limits='Viewport counters and encoded mesh buffers are desktop samples; they do not establish FPS, GPU time or device performance.'),indent=2)+'\n')
print(json.dumps(dict(totals=totals,geometry=rows),indent=2))
