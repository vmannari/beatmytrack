"""CI02: compare sampled surfaces, connectivity and untouched encoded corners."""
import collections
import json
from pathlib import Path
import numpy as np
from run_car_pass10 import WORK, OUT


def distance(points, triangles):
    """Closest point on each closed triangle (plane interior or its three edges)."""
    worst = 0.0
    a, b, c = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    ab, ac = b-a, c-a
    normal = np.cross(ab, ac)
    n2 = np.sum(normal*normal, axis=1)
    dot00, dot01, dot11 = np.sum(ab*ab, axis=1), np.sum(ab*ac, axis=1), np.sum(ac*ac, axis=1)
    denominator = dot00*dot11-dot01*dot01
    for start in range(0, len(points), 64):
        p = points[start:start+64, None, :]
        pa = p-a
        dot20, dot21 = np.sum(pa*ab, axis=2), np.sum(pa*ac, axis=2)
        v = (dot11*dot20-dot01*dot21)/np.maximum(denominator, 1e-30)
        w = (dot00*dot21-dot01*dot20)/np.maximum(denominator, 1e-30)
        inside = (v >= -1e-8) & (w >= -1e-8) & (v+w <= 1+1e-8) & (n2 > 1e-24)
        best = np.where(inside, np.sum(pa*normal, axis=2)**2/np.maximum(n2, 1e-30), np.inf)
        for low, high in ((a, b), (b, c), (c, a)):
            edge = high-low
            factor = np.clip(np.sum((p-low)*edge, axis=2)/np.maximum(np.sum(edge*edge, axis=1), 1e-30), 0, 1)
            delta = p-low-factor[..., None]*edge
            best = np.minimum(best, np.sum(delta*delta, axis=2))
        worst = max(worst, float(np.sqrt(np.min(best, axis=1)).max(initial=0)))
    return worst


def topology(vertices, indices, reference=None):
    # Split collinear T junctions before counting boundaries. A long edge and
    # the same edge represented by two segments cover the same closed surface.
    reference=np.array(reference if reference is not None else vertices)
    epsilon=0.000001
    positions=[];buckets={};identities={}
    for point in reference:
        code=tuple(float(x) for x in point)
        if code in identities:continue
        cell=tuple(int(np.floor(x/epsilon)) for x in point);found=None
        for x in (-1,0,1):
            for y in (-1,0,1):
                for z in (-1,0,1):
                    for candidate in buckets.get((cell[0]+x,cell[1]+y,cell[2]+z),[]):
                        if sum((code[i]-positions[candidate][i])**2 for i in range(3))<=epsilon**2:found=candidate;break
                    if found is not None:break
                if found is not None:break
            if found is not None:break
        if found is None:
            found=len(positions);positions.append(code);buckets.setdefault(cell,[]).append(found)
        identities[code]=found
    pool=np.array(positions)
    welded=np.array([identities[tuple(float(x) for x in point)] for point in vertices])
    parents=list(range(len(pool)))
    def root(at):
        while parents[at]!=at:
            parents[at]=parents[parents[at]];at=parents[at]
        return at
    edges=collections.Counter()
    face_count=0
    for face in welded[indices]:
        if len(set(face))<3 or np.linalg.norm(np.cross(pool[face[1]]-pool[face[0]],pool[face[2]]-pool[face[0]]))<=1e-15:continue
        face_count+=1
        for low,high in ((face[0],face[1]),(face[1],face[2]),(face[2],face[0])):
            if low==high:continue
            a,b=pool[low],pool[high];edge=b-a;length2=float(edge@edge)
            candidates=np.flatnonzero(np.all(pool>=np.minimum(a,b)-epsilon*1.5,axis=1)&np.all(pool<=np.maximum(a,b)+epsilon*1.5,axis=1))
            t=(pool[candidates]-a)@edge/length2
            exact=np.linalg.norm(pool[candidates]-a-t[:,None]*edge,axis=1)<epsilon*1.5
            points=candidates[exact][np.argsort(t[exact])]
            for one,two in zip(points,points[1:]):
                pair=tuple(sorted((int(one),int(two))));edges[pair]+=1
                parents[root(int(one))]=root(int(two))
    active={at for edge in edges for at in edge}
    components=len({root(at) for at in active})
    boundary=[pair for pair,count in edges.items() if count==1]
    boundary_parents={}
    def boundary_root(at):
        boundary_parents.setdefault(at,at)
        while boundary_parents[at]!=at:at=boundary_parents[at]
        return at
    for low,high in boundary:boundary_parents[boundary_root(low)]=boundary_root(high)
    boundary_positions=sorted(tuple(sorted((tuple(pool[low]),tuple(pool[high])))) for low,high in boundary)
    import hashlib
    digest=hashlib.sha256(json.dumps(boundary_positions).encode()).hexdigest()
    return {'boundary_segments':digest,'components':components,'boundary_components':len({boundary_root(at) for at in boundary_parents}),'euler':len(active)-len(edges)+face_count, 'nonmanifold_edges':sum(count>2 for count in edges.values())}


def verify_fields(source,surface,witnesses,contacts):
    after=np.array(surface['after']);before=np.array(surface['before']);faces=np.array(surface['before_indices']).reshape(-1,3)
    if not witnesses:return set(surface['after_attributes']).issubset(set(surface['before_attributes']))
    if len(witnesses)!=len(after):return False
    ids=faces[np.array([w['triangle'] for w in witnesses],dtype=int)]
    factors=np.array([w['weights'] for w in witnesses])
    if np.min(factors)<-1e-7 or np.max(abs(factors.sum(axis=1)-1))>1e-6:return False
    expected=(before[ids]*factors[...,None]).sum(axis=1)
    if np.linalg.norm(after-expected,axis=1).max()>0.002:return False
    actual=surface['after_fields']
    for name,tolerance in [('normals',0.0002),('uv',0.00002),('uv2',0.00002),('colors',1/255+1e-6)]:
        if not source[name]:
            if actual[name]:return False
            continue
        values=(np.array(source[name])[ids]*factors[...,None]).sum(axis=1)
        if name=='normals':values/=np.maximum(np.linalg.norm(values,axis=1)[:,None],1e-20)
        if np.max(abs(np.array(actual[name])-values))>tolerance:return False
    for vertex in contacts:
        if np.linalg.norm(after-before[int(vertex)],axis=1).min()>0.0000002:return False
    return True


def main():
    geometry = json.loads((WORK/'proof-geometry.json').read_text())
    plan = json.loads((OUT/'candidate-plan.json').read_text())
    assert plan['parts'] and set(geometry)==set(plan['parts']), 'Every nonempty candidate must have an exported proof'
    sources=json.loads((WORK/'retessellation-input.json').read_text())
    results = {}
    for ordinal,(key, surfaces) in enumerate(geometry.items()):
        if ordinal%75==0: print("CAR15_GEOMETRY",ordinal,len(geometry),flush=True)
        bundle=surfaces
        surfaces=bundle['surfaces'] if isinstance(bundle,dict) else bundle
        projected=plan['parts'][key].get('kind')=='projected'
        source_key=plan['parts'][key].get('source_key',key)
        details = []
        for number,surface in enumerate(surfaces):
            before, after = np.array(surface['before']), np.array(surface['after'])
            prior = np.array(surface['before_indices']).reshape(-1, 3)
            current = np.array(surface['after_indices']).reshape(-1, 3)
            old_tri, new_tri = before[prior], after[current]
            samples_before = np.concatenate((before[np.unique(prior)], old_tri.mean(axis=1)))
            samples_after = np.concatenate((after[np.unique(current)], new_tri.mean(axis=1)))
            error = max(distance(samples_before, new_tri), distance(samples_after, old_tri))
            pool=np.concatenate((before,after))
            old_topology, new_topology = topology(before, prior,pool), topology(after, current,pool)
            surface_contacts=bundle.get('surface_contacts',[])
            contact_error=distance(before[np.array(surface_contacts[number],dtype=int)],new_tri) if surface_contacts and surface_contacts[number] else 0.0
            attributes_exact = verify_fields(sources[source_key]['surfaces'][number],surface,bundle['witnesses'][number],bundle['contacts'][number]) if projected else set(surface['after_attributes']).issubset(set(surface['before_attributes']))
            topology_ok = ((projected or old_topology['boundary_segments']==new_topology['boundary_segments']) and old_topology['components'] == new_topology['components'] and old_topology['euler']==new_topology['euler'] and
                           old_topology['boundary_components'] == new_topology['boundary_components'] and
                           new_topology['nonmanifold_edges'] <= old_topology['nonmanifold_edges'])
            details.append({'maximum_sampled_deviation_m': error, 'original_fields_validated': attributes_exact, 'encoded_corners_exact': attributes_exact if not projected else None,
                            'before_topology': old_topology, 'after_topology': new_topology,
                            'topology_ok': topology_ok,'contact_surface_error_m':contact_error})
        results[key] = {'name': plan['parts'][key]['name'], 'vehicle': plan['parts'][key]['vehicle'], 'surfaces': details,
                        'accepted': all(x['original_fields_validated'] and x['topology_ok'] and x['contact_surface_error_m']<=0.0000003 and x['maximum_sampled_deviation_m']*plan['parts'][key]['maximum_scale'] <= 0.002 for x in details)}
    report = {'parts': results, 'accepted': sum(x['accepted'] for x in results.values()),
              'rejected': sum(not x['accepted'] for x in results.values()),
              'limit_m': 0.002, 'sampling': 'All used vertices and all triangle centroids, both directions; local source units.'}
    (OUT/'geometry-review.json').write_text(json.dumps(report, indent=2)+'\n')
    for car in ('compact', 'kart', 'forklift', 'electric', 'hovercraft'):
        savings = sum((p['before']-p['after'])*p['stock_instances'] for key, p in plan['parts'].items() if p['vehicle'] == car and results[key]['accepted'])
        print(car, 'accepted savings', savings, f"{savings/plan['before'][car]*100:.2f}%")
    print('GEOMETRY_REVIEW', report['accepted'], 'accepted;', report['rejected'], 'rejected')


if __name__ == '__main__':
    main()
