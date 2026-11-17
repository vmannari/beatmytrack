"""Regular angular racing tyre profiles, with original surface field witnesses."""
import collections,json,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/car-pass12-2026-11-16'
data=json.loads((WORK/'retessellation-input.json').read_text())
rows=json.loads((ROOT/'docs/evidence/car-pass12-2026-11-16/survey.json').read_text())
sys.path.insert(0,str(ROOT/'scripts'))
from car_pass12_contacts import collect_anchors
anchors=collect_anchors(WORK,rows)
output={}
for key,piece in data.items():
    if sum(len(sf['indices'])//3 for sf in piece['surfaces'])!=448 and piece['name']!='SlickTyre':continue
    assert len(piece['surfaces'])==1
    source=piece['surfaces'][0]
    old=[Vector(p) for p in source['vertices']]
    faces=[source['indices'][at:at+3] for at in range(0,len(source['indices']),3)]
    tree=BVHTree.FromPolygons(old,faces,all_triangles=True)
    profile=sorted({(round(p.x,7),round(math.hypot(p.y,p.z),7)) for p in old},key=lambda p:p[0])
    # The ordered source profile folds at the shoulders; source UV rows retain it.
    groups=collections.defaultdict(list)
    for i,p in enumerate(old):groups[(round(p.x,5),round(math.hypot(p.y,p.z),5))].append(i)
    profile=[]
    for code,ids in sorted(groups.items(),key=lambda item:sum(source['uv'][i][1] for i in item[1])/len(item[1])):
        p=old[min(ids,key=lambda i:abs(source['uv'][i][0]))]
        profile.append((p.x,math.hypot(p.y,p.z)))
    assert len(profile) in (8,10)
    for columns in ((24,22,20,18,16) if key.startswith("kart_") else (28,26,24)):
      for lift in (0.0,0.0003,0.0006,0.0009,0.0012):
          vertices=[];normals=[];uv=[];witnesses=[];indices=[]
          for row,(x,radius) in enumerate(profile):
              for col in range(columns+1):
                  angle=col/columns*math.tau
                  source_columns=28 if key.startswith('kart_') else 32
                  half=math.pi/source_columns;local=(angle%(2*half))-half
                  adjusted=radius*math.cos(half)/math.cos(local)+lift
                  p=Vector((x,max(-radius,min(radius,math.sin(angle)*adjusted)),max(-radius,min(radius,math.cos(angle)*adjusted))))
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
          output[key+'@regular'+str(columns)+'lift'+str(lift)]=[dict(vertices=vertices,normals=normals,uv=uv,uv2=[],colors=[],tangents=[],indices=indices,witnesses=witnesses,contact_vertices=[])]
          print('REGULAR_TYRE',columns,len(indices)//3,'contacts',len(anchors[(key,0)]))
(WORK/'regular-wheels-remeshed.json').write_text(json.dumps(output,separators=(',',':')))
