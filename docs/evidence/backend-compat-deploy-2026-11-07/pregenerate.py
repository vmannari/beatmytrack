"""Local native drives only; no backend writes or uploaded scores."""
import json
import time
from pathlib import Path
from bmt_backend.config import Settings
from bmt_backend.test_drivers import profile
from bmt_backend.test_driver_generator import generate,controller_engine
from bmt_backend.test_population_tool import atomic_save,recording
from bmt_backend.track_models import digest

root=Path('/release')
document=json.loads((root/'daily-document.json').read_text())
_,_,traits=profile(202611071,0,1,0.8,0.8)
settings=Settings(environment='test',godot_bin='/usr/local/bin/godot',game_project='/opt/bmt/game',object_dir='/release/drive-cache/objects')
with controller_engine(settings) as verifier:
    manifest=verifier.manifest()
class Source:
    def call(self,method,path):
        assert method=='GET' and path=='/track-versions/pregeneration/document'
        return document
for car in ('compact','electric','forklift','hovercraft','kart'):
    target=root/('pregenerated-'+car+'.json')
    if target.exists():
        continue
    deadline=time.monotonic()+600
    def bounded(*args,**kwargs):
        return generate(*args,**kwargs,deadline=deadline)
    result=recording(Source(),{'vehicle_id':car,'pace_scales':{},'manifest':manifest},
        {'id':'pregenerate-'+car,'version_id':'pregeneration','content_hash':digest(document),'attempt':0},
        {'traits':traits},settings,root/'pregenerate-state.json',generator=bounded)
    atomic_save(target,{'content_hash':digest(document),'vehicle_id':car,'result':result})
    print(json.dumps({'car':car,'native_ticks':result['time_ticks'],'local_only':True}),flush=True)
