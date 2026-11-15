"""Regular angular racing tyre profiles, with original surface field witnesses."""
import collections,json,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/car-step10-2026-11-15'
data=json.loads((WORK/'retessellation-input.json').read_text())
rows=json.loads((ROOT/'docs/evidence/car-step10-2026-11-15/survey.json').read_text())
sys.path.insert(0,str(ROOT/'scripts'))
from car_step10_contacts import collect_anchors
anchors=collect_anchors(WORK,rows)
output={}
for key,piece in data.items():
    if not key.startswith('kart_') or piece['name']!='SlickTyre':continue
    assert len(piece['surfaces'])==1
    source=piece['surfaces'][0]
    old=[Vector(p) for p in source['vertices']]
    faces=[source['indices'][at:at+3] for at in range(0,len(source['indices']),3)]
    tree=BVHTree.FromPolygons(old,faces,all_triangles=True)
    profile=sorted({(round(p.x,7),round(math.hypot(p.y,p.z),7)) for p in old},key=lambda p:p[0])
    # The ordered source profile folds at the shoulders; source UV rows retain it.
    profile=[]
    for v in sorted({round(uv[1],6) for uv in source['uv']}):
        ids=[i for i,uv in enumerate(source['uv']) if abs(uv[1]-v)<1e-5]
        p=old[min(ids,key=lambda i:abs(source['uv'][i][0]))]
        profile.append((p.x,math.hypot(p.y,p.z)))
    assert len(profile)==10
    for columns in (30,28,24):
        vertices=[];normals=[];uv=[];witnesses=[];indices=[]
        for row,(x,radius) in enumerate(profile):
            for col in range(columns+1):
                angle=col/columns*math.tau;p=Vector((x,math.sin(angle)*radius,math.cos(angle)*radius))
                nearest=tree.find_nearest(p);hits=tree.find_nearest_range(p,nearest[3]+1e-7)
                hit=min(hits,key=lambda h:abs(sum(source['uv'][i][0] for i in faces[h[2]])/3-col/columns))
                ids=faces[hit[2]];a,b,c=[old[i] for i in ids];ab=b-a;ac=c-a;ap=hit[0]-a
                denominator=ab.dot(ab)*ac.dot(ac)-ab.dot(ac)**2
                v=(ac.dot(ac)*ap.dot(ab)-ab.dot(ac)*ap.dot(ac))/denominator
                w=(ab.dot(ab)*ap.dot(ac)-ab.dot(ac)*ap.dot(ab))/denominator
                f=[max(0,1-v-w),max(0,v),max(0,w)];f=[value/sum(f) for value in f]
                n=sum((Vector(source['normals'][i])*weight for i,weight in zip(ids,f)),Vector()).normalized()
                vertices.append(list(p));normals.append(list(n));uv.append([sum(source['uv'][i][axis]*weight for i,weight in zip(ids,f)) for axis in range(2)])
                witnesses.append({'triangle':hit[2],'weights':f})
        for row in range(len(profile)-1):
            for col in range(columns):
                a=row*(columns+1)+col
                for face in [[a,a+1,a+columns+2],[a,a+columns+2,a+columns+1]]:
                    ps=[Vector(vertices[i]) for i in face]
                    if (ps[1]-ps[0]).cross(ps[2]-ps[0]).dot(sum((Vector(normals[i]) for i in face),Vector()))>0:face.reverse()
                    indices.extend(face)
        output[key+'@regular'+str(columns)]=[dict(vertices=vertices,normals=normals,uv=uv,uv2=[],colors=[],tangents=[],indices=indices,witnesses=witnesses,contact_vertices=sorted(anchors[(key,0)]))]
        print('REGULAR_TYRE',columns,len(indices)//3,'contacts',len(anchors[(key,0)]))
(WORK/'regular-remeshed.json').write_text(json.dumps(output,separators=(',',':')))
