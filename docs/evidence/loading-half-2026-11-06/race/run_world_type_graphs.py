"""Serial fresh-process graph probes; no native rendering or source mutations."""
import json
from pathlib import Path
import subprocess
import sys

out = Path(__file__).resolve().parent
spec = json.loads((out/'world-type-prototype.json').read_text())
for label, target in [('showroom','ui/car_showroom.gd'),('pictures','ui/garage_preview_cache.gd'),('memory','editor/editor_memory.gd')]:
    for arm in ['control','candidate']:
        name = 'race/graph-'+label+'-'+arm
        subprocess.run([sys.executable,str(out.parent/'run_case.py'),name,'profile_world_type_graph.gd',
                        '--project',spec['projects'][arm],'--timeout','90','--args','--target=res://'+target],check=True)
        result = json.loads((out/('graph-'+label+'-'+arm)/'result.json').read_text())
        print(json.dumps({'label':label,'arm':arm,**result}),flush=True)
