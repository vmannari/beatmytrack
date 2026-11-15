"""Move only this task's superseded frame maps back into disposable output."""
import json
import shutil
from run_rally_front import ROOT,OUT,WORK
receipt=json.loads((OUT/'recipe-migration.json').read_text())
archive=(WORK/'draft-recipes').resolve();archive.mkdir(parents=True,exist_ok=True)
allowed=(ROOT/'game/assets/vehicles/car_detail_v1').resolve()
for name in receipt:
    source=(ROOT/'game'/name.removeprefix('res://')).resolve()
    target=(archive/source.name).resolve()
    assert source.is_relative_to(allowed) and source.name.startswith('compact_') and target.is_relative_to(WORK.resolve()) and not target.exists()
    shutil.move(str(source),str(target))
(OUT/'recipe-migration-draft.json').write_bytes((OUT/'recipe-migration.json').read_bytes())
print('RALLY_FRONT_DRAFTS',len(receipt),'task-owned superseded frame maps moved to build retention')
