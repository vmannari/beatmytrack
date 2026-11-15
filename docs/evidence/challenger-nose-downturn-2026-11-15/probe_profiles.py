from pathlib import Path
import json,numpy as np
b=Path('build/challenger-nose-downturn-2026-11-15')
for name in ['baseline','candidate']:
 p=np.asarray(json.loads((b/(name+'.json')).read_text())['simple']['body_paint']['points'])
 for z in [-2.075,-2.05,-2.025,-2.0]:
  q=p[(abs(p[:,2]-z)<.0125)&(p[:,1]>.65)];print(name,z, q.min(0) if len(q) else 'empty',q.max(0) if len(q) else '')
