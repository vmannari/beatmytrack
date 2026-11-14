from pathlib import Path
import json
import sys
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_reference_geometry import nose_plan_points,nose_plan_normals,nose_plan_scale
rows=np.asarray(json.loads((OUT/'runtime-plan.json').read_text()))
p=np.c_[rows[:,0],np.zeros(len(rows)),rows[:,1]]
agreement=float(np.max(abs(nose_plan_points(p)[:,0]-rows[:,2])))
assert agreement<1e-10
rng=np.random.default_rng(13112026)
p=rng.uniform([-1,.3,-2.4],[1,1.2,-1.4],(10000,3))
n=rng.normal(size=p.shape);n/=np.linalg.norm(n,axis=1,keepdims=True)
e=1e-6
jac=np.stack([(nose_plan_points(p+np.eye(3)[axis]*e)-nose_plan_points(p-np.eye(3)[axis]*e))/(2*e) for axis in range(3)],axis=-1)
normal=np.linalg.solve(np.swapaxes(jac,-1,-2),n)
normal/=np.linalg.norm(normal,axis=1,keepdims=True)
error=float(np.max(np.linalg.norm(normal-nose_plan_normals(p,n),axis=1)))
minimum=float(nose_plan_scale(np.linspace(-2.5,1,50000))[0].min())
assert error<1e-7 and minimum>.9
receipt={'runtime_stations':len(rows),'runtime_offline_max_error_metres':agreement,
         'normal_jacobian_samples':len(p),'normal_max_error':error,'minimum_determinant':minimum}
(OUT/'transform-contract.json').write_text(json.dumps(receipt,indent=2));print(receipt)
