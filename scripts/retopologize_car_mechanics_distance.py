"""CME03: topology-preserving endpoint collapses for distant duct/guard rings."""
from pathlib import Path
import collections
import json
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/car-mechanics-2026-11-17'
inputs=json.loads((WORK/'distance-proof-input.json').read_text())
(WORK/'distance-engine-prototypes.json').write_text(json.dumps(inputs))
output={}
for key,row in inputs.items():
    vectors=[Vector(p) for p in row['vertices']]
    unique={};representatives={};mapped=[]
    for at,p in enumerate(vectors):
        code=tuple(round(v,6) for v in p)
        if code not in unique:
            unique[code]=len(unique);representatives[unique[code]]=at
        mapped.append(unique[code])
    positions={i:vectors[at] for i,at in representatives.items()}
    faces=[tuple(mapped[i] for i in row['before'][at:at+3]) for at in range(0,len(row['before']),3)]
    target=int(len(faces)*.80)
    while len(faces)>target:
        neighbors=collections.defaultdict(set);edges=collections.defaultdict(list)
        for number,tri in enumerate(faces):
            for a,b in zip(tri,tri[1:]+tri[:1]):
                neighbors[a].add(b);neighbors[b].add(a)
                edges[tuple(sorted((a,b)))].append(number)
        chosen=None
        for (u,v),attached in sorted(edges.items(),key=lambda item:(positions[item[0][0]]-positions[item[0][1]]).length_squared):
            if len(attached)!=2:continue
            opposite=set(i for f in attached for i in faces[f])-{u,v}
            if neighbors[u]&neighbors[v]!=opposite:continue
            for keep,remove in ((u,v),(v,u)):
                candidate=[];valid=True
                for tri in faces:
                    if keep in tri and remove in tri:continue
                    next_tri=tuple(keep if i==remove else i for i in tri)
                    if remove in tri:
                        a,b,c=(positions[i] for i in tri)
                        x,y,z=(positions[i] for i in next_tri)
                        old=(b-a).cross(c-a);new=(y-x).cross(z-x)
                        if new.length_squared<1e-16 or old.normalized().dot(new.normalized())<.25:
                            valid=False;break
                    candidate.append(next_tri)
                if valid:
                    chosen=candidate;break
            if chosen is not None:break
        if chosen is None:break
        faces=chosen
    row['after']=[representatives[i] for tri in faces for i in tri]
    output[key]=row['after']
    print('TOPOLOGY_DISTANCE',key,len(row['before'])//3,len(row['after'])//3,flush=True)
(WORK/'distance-retopology.json').write_text(json.dumps(output))
(WORK/'distance-proof-input.json').write_text(json.dumps(inputs))
