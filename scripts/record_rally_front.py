"""Bind the five authored production files to their exact source checkpoint."""
import hashlib
import json
from run_rally_front import ROOT,WORK,OUT
digest=lambda data:hashlib.sha256(data).hexdigest()
modified=['game/vehicle/compact_grille.gd','game/vehicle/compact_front_lamps.gd']
added=['game/assets/vehicles/car_detail_v1/compact_front_lens.gdshader']
added += ['game/'+name.removeprefix('res://') for name in json.loads((OUT/'recipe-migration.json').read_text())]
uid=added[0]+'.uid'
if (ROOT/uid).exists():added.append(uid)
files={name:dict(before=digest((WORK/'before'/name).read_bytes()) if name in modified else None,
    after=digest((ROOT/name).read_bytes())) for name in modified+added}
(OUT/'publication.json').write_text(json.dumps(dict(files=files,authored_model='compact',
    recipe_frames=2,other_models_authored=False,derived_shared_consumer='super_rally'),indent=2)+'\n')
print('RALLY_FRONT_PUBLICATION',len(files),'source/UID bindings')
