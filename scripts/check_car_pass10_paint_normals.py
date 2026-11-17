import json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=Path(__file__).resolve().parents[1];w=r/'build/car-pass10-2026-11-16';o=r/'docs/evidence/car-pass10-2026-11-16'
g=json.loads((w/'proof-geometry.json').read_text());data=json.loads((w/'retessellation-input.json').read_text());plan=json.loads((o/'selected-plan.json').read_text());rows=[]
def weights(p,a,b,c):
 ab=b-a;ac=c-a;ap=p-a;den=ab.dot(ab)*ac.dot(ac)-ab.dot(ac)**2
 if abs(den)<1e-25:return [1,0,0]
 v=(ac.dot(ac)*ap.dot(ab)-ab.dot(ac)*ap.dot(ac))/den;z=(ab.dot(ab)*ap.dot(ac)-ab.dot(ac)*ap.dot(ab))/den
 f=[max(0,1-v-z),max(0,v),max(0,z)];total=sum(f);return [x/total for x in f]
for key,piece in plan['parts'].items():
 if piece['vehicle']!='electric' or piece['name'] not in ['ReferenceHood','ReferenceRearDeck']:continue
 maximum=0
 for no,s in enumerate(g[key]['surfaces']):
  old=[Vector(p) for p in s['before']];faces=[s['before_indices'][i:i+3] for i in range(0,len(s['before_indices']),3)];normals=[Vector(n) for n in data[key]['surfaces'][no]['normals']];tree=BVHTree.FromPolygons(old,faces,all_triangles=True)
  points=[Vector(p) for p in s['after']];n=[Vector(p) for p in s['after_fields']['normals']]
  for i in range(0,len(s['after_indices']),3):
   tri=s['after_indices'][i:i+3];p=sum((points[j] for j in tri),Vector())/3;actual=sum((n[j] for j in tri),Vector()).normalized();h=tree.find_nearest(p);ids=faces[h[2]];f=weights(h[0],*(old[j] for j in ids));expected=sum((normals[j]*v for j,v in zip(ids,f)),Vector()).normalized();maximum=max(maximum,math.degrees(actual.angle(expected)))
 rows.append({'name':piece['name'],'maximum_centroid_normal_field_error_degrees':maximum});print('CP3_VOLT_NORMALS',rows[-1])
(o/'paint-normal-fields.json').write_text(json.dumps(rows,indent=2)+'\n')

assert all(row['maximum_centroid_normal_field_error_degrees']<1.0 for row in rows)
