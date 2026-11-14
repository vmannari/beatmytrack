from pathlib import Path
import sys,json
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_reference_geometry import nose_distance,nose_inverse
rows=np.array(json.loads((OUT/'nose-runtime.json').read_text()))
agreement=float(np.max(abs(-nose_distance(-rows[:,1],rows[:,0])[0]-rows[:,2])))
assert agreement<3e-6
distance=np.linspace(1.60,2.20,20001);minimum=1.;error=0.
for x in np.linspace(-1.1,1.1,23):
    value,derivative,_=nose_distance(distance,x)
    minimum=min(minimum,float(derivative.min()))
    error=max(error,float(np.max(abs(nose_inverse(-value,x)[0]+distance))))
assert minimum>.25 and error<1e-8
result={'runtime_offline_stations':len(rows),'agreement_metres':agreement,'minimum_longitudinal_jacobian':minimum,'maximum_inverse_error_metres':error,'leading_extension_metres':float(nose_distance(2.1171,0.9)[0]-2.1171)}
(OUT/'nose-contract.json').write_text(json.dumps(result,indent=2))
print(result)
