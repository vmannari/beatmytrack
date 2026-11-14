from pathlib import Path
import sys,json
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_reference_geometry import nose_corner_field,nose_corner_normals
rng=np.random.default_rng(13112026)
p=rng.uniform([-1,.25,-2.35],[1,1.2,-1.3],(20000,3))
q,jac=nose_corner_field(p);e=1e-6
numeric=np.stack([(nose_corner_field(p+np.eye(3)[axis]*e)[0]-nose_corner_field(p-np.eye(3)[axis]*e)[0])/(2*e) for axis in range(3)],axis=-1)
error=float(np.max(abs(jac-numeric)))
n=rng.normal(size=p.shape);n/=np.linalg.norm(n,axis=1,keepdims=True)
normal=np.linalg.solve(np.swapaxes(numeric,-1,-2),n);normal/=np.linalg.norm(normal,axis=1,keepdims=True)
normal_error=float(np.max(np.linalg.norm(normal-nose_corner_normals(p,n),axis=1)))
det=float(np.linalg.det(jac).min())
assert error<1e-7 and normal_error<1e-7 and det>.7
assert np.array_equal(q[p[:,2]>=-1.82],p[p[:,2]>=-1.82])
hood=np.c_[rng.uniform(-.70,.70,10000),rng.uniform(.8,1.05,10000),rng.uniform(-2.3,-1.3,10000)]
# All actually used fitted-bonnet positions lie within this half-width.
hood[:,0]=np.clip(hood[:,0],-.69,.70)
assert np.array_equal(nose_corner_field(hood)[0],hood)
record={'jacobian_samples':len(p),'maximum_jacobian_error':error,'maximum_normal_error':normal_error,
        'minimum_determinant':det,'maximum_downturn_metres':float(np.max(p[:,1]-q[:,1])),
        'maximum_corner_return_metres':float(np.max(q[:,2]-p[:,2])),'fitted_bonnet_samples_fixed':len(hood)}
(OUT/'corner-transform-contract.json').write_text(json.dumps(record,indent=2));print(record)
