"""C1502: bind selected resource hashes to their strict geometry review receipts."""
import collections
import hashlib
import json
import numpy as np
from run_car15 import ROOT, OUT, WORK
from check_car15_geometry import topology

plan = json.loads((OUT/'selected-plan.json').read_text())
reviews = {family:json.loads((OUT/(family+'-geometry-review.json')).read_text())
           for family in ('locked','projected-final')}
rows = {}
for source, part in plan['parts'].items():
    proof = reviews[part['family']]['parts'][part['review_key']]
    assert proof['accepted'], source
    assert part['maximum_error'] <= 0.002, source
    assert hashlib.sha256((WORK/'candidates'/part['file']).read_bytes()).hexdigest() == part['sha256'], source
    assert 'SteeringAssembly' not in part.get('path',''), source
    rows[source] = dict(vehicle=part['vehicle'], file=part['file'], sha256=part['sha256'],
                        family=part['family'], maximum_world_sampled_deviation_m=part['maximum_error'],
                        geometry=proof)
# An equivalent collinear subdivision is accepted; a real missing face changes
# the closed square's topology. Keep both controls for the T-junction handling.
points = np.array([[0,0,0],[1,0,0],[1,1,0],[0,1,0],[.5,.5,0]], dtype=float)
plain = topology(points, np.array([[0,1,2],[0,2,3]]))
split = topology(points, np.array([[0,1,4],[1,2,4],[0,2,3]]))
hole = topology(points, np.array([[0,1,4],[0,2,3]]))
assert all(plain[k] == split[k] for k in ('components','boundary_components','euler','nonmanifold_edges'))
assert any(plain[k] != hole[k] for k in ('boundary_components','euler','boundary_segments'))
receipt = dict(selected_parts=len(rows), families=dict(collections.Counter(p['family'] for p in plan['parts'].values())),
               limit_m=.002, maximum_world_sampled_deviation_m=max(p['maximum_error'] for p in plan['parts'].values()),
               equivalent_subdivision_control=True, missing_face_rejected=True,
               sampling='Every used vertex and triangle centroid, both directions; sampled rather than exhaustive surface distance.',
               parts=rows)
(OUT/'selected-geometry.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('CAR15_SELECTED_GEOMETRY',len(rows),'accepted; max',receipt['maximum_world_sampled_deviation_m'],'m; both topology controls pass')
