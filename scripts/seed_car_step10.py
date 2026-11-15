"""Protect visible joins/landmarks before proposing another small geometry step."""
import collections
import json
from run_car_step10 import OUT
rows=json.loads((OUT/'survey.json').read_text())
blocked=set();reasons=collections.Counter();totals=collections.Counter();eligible=collections.Counter()
terms=('helmet','driver','steeringassembly','glass','glazing','seal','roof','pillar','window','cabin','arch','contour','seam','mirror','lamp','lens','optical','canopy','handle','grille','accent','inlay','stripe','decal','sticker','highlight','shine','letter','plate')
for row in rows:
    reason=None
    label=(row['name']+' '+row['path']).lower()
    if row['blend_shapes']:reason='morph'
    elif row.get('authored') or row.get('guide_locked'):reason='authored profile'
    elif any(shader!='StandardMaterial3D' for shader in row['shaders']):reason='shader/displacement'
    elif any(term in label for term in terms):reason='visible landmark/join'
    elif row['vehicle']=='electric' and row['name'].startswith('ReferenceSide'):reason='repaired door backing'
    elif row['triangles']<24:reason='already small'
    if reason:blocked.add(row['key']);reasons[reason]+=1
    if row['mode']=='stock':totals[row['vehicle']]+=row['triangles']
for row in rows:
    if row['mode']=='stock' and row['key'] not in blocked:eligible[row['vehicle']]+=row['triangles']
(OUT/'candidate-plan.json').write_text(json.dumps(dict(parts={},before=dict(totals),blocked_keys=sorted(blocked),scope=['compact','kart','forklift','electric','hovercraft'],excludes='super_rally'),indent=2)+'\n')
(OUT/'protection.json').write_text(json.dumps(dict(reasons=dict(reasons),stock_triangles=dict(totals),eligible_triangles=dict(eligible),blocked_meshes=len(blocked)),indent=2)+'\n')
print('CAR_STEP10_BASELINES',dict(totals),'eligible',dict(eligible),'blocked',len(blocked))
