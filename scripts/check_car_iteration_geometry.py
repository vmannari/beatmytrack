"""CI02: compare sampled surfaces, connectivity and untouched encoded corners."""
import collections
import json
from pathlib import Path
import numpy as np
from run_car_iteration import WORK, OUT


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


def topology(vertices, indices):
    _, welded = np.unique(np.round(vertices*1e6).astype(np.int64), axis=0, return_inverse=True)
    faces = welded[indices]
    parents = list(range(int(welded.max())+1))
    def root(at):
        while parents[at] != at:
            parents[at] = parents[parents[at]]
            at = parents[at]
        return at
    edges = collections.Counter()
    for a, b, c in faces:
        for low, high in ((a, b), (b, c), (c, a)):
            edges[tuple(sorted((int(low), int(high))))] += 1
            parents[root(int(low))] = root(int(high))
    components = len({root(int(at)) for at in faces.flat})
    boundary = [pair for pair, count in edges.items() if count == 1]
    boundary_parents = {}
    def boundary_root(at):
        boundary_parents.setdefault(at, at)
        while boundary_parents[at] != at:
            at = boundary_parents[at]
        return at
    for low, high in boundary:
        boundary_parents[boundary_root(low)] = boundary_root(high)
    return {'components': components, 'boundary_components': len({boundary_root(at) for at in boundary_parents}),
            'nonmanifold_edges': sum(count > 2 for count in edges.values())}


def main():
    geometry = json.loads((WORK/'proof-geometry.json').read_text())
    plan = json.loads((OUT/'candidate-plan.json').read_text())
    results = {}
    for key, surfaces in geometry.items():
        details = []
        for surface in surfaces:
            before, after = np.array(surface['before']), np.array(surface['after'])
            prior = np.array(surface['before_indices']).reshape(-1, 3)
            current = np.array(surface['after_indices']).reshape(-1, 3)
            old_tri, new_tri = before[prior], after[current]
            samples_before = np.concatenate((before[np.unique(prior)], old_tri.mean(axis=1)))
            samples_after = np.concatenate((after[np.unique(current)], new_tri.mean(axis=1)))
            error = max(distance(samples_before, new_tri), distance(samples_after, old_tri))
            old_topology, new_topology = topology(before, prior), topology(after, current)
            attributes_exact = set(surface['after_attributes']).issubset(set(surface['before_attributes']))
            topology_ok = (old_topology['components'] == new_topology['components'] and
                           old_topology['boundary_components'] == new_topology['boundary_components'] and
                           new_topology['nonmanifold_edges'] <= old_topology['nonmanifold_edges'])
            details.append({'maximum_sampled_deviation_m': error, 'encoded_corners_exact': attributes_exact,
                            'before_topology': old_topology, 'after_topology': new_topology,
                            'topology_ok': topology_ok})
        results[key] = {'name': plan['parts'][key]['name'], 'vehicle': plan['parts'][key]['vehicle'], 'surfaces': details,
                        'accepted': all(x['encoded_corners_exact'] and x['topology_ok'] and x['maximum_sampled_deviation_m'] <= 0.002 for x in details)}
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
