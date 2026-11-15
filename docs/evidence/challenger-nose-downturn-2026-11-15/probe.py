from pathlib import Path
import sys,json,numpy as np
sys.path.insert(0,str(Path.cwd()/'scripts'))
from challenger_nose_finish import point_map
b=json.loads((Path('build/challenger-nose-downturn-2026-11-15/baseline.json')).read_text())
for name,row in b['full'].items():
 p=np.asarray(row['points']);e=.000025;c=[]
 for axis in range(3):
  d=np.zeros(3);d[axis]=e;c.append((point_map(p+d)-point_map(p-d))/(2*e))
 det=np.sum(c[0]*np.cross(c[1],c[2]),axis=1);i=det.argmin()
 if det[i]<.75:print(name,'min Jacobian',det[i],'at',p[i])
