"""Freeze the matching app without changing owner saves or the shared Git index."""
import importlib.util
import json
import shutil
from pathlib import Path
WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/race-verification-speed-2026-11-07'
spec=importlib.util.spec_from_file_location('previous_release',ROOT/'build/backend-compat-deploy-20261107/deploy.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
r.WORK=WORK;r.OUT=OUT;r.FROZEN=WORK/'frozen'
r.d.WORK=WORK;r.d.OUT=OUT;r.d.STATE=WORK/'snapshot-state.private.json'
r.s={};r.d.state=r.s
r.freeze()
for name in ('export.py','import_project.py'):
    shutil.copyfile(ROOT/'build/backend-compat-deploy-20261107'/name,WORK/name)
target=r.FROZEN/'.tools/admob/android_source.zip'
target.parent.mkdir(parents=True,exist_ok=True)
shutil.copyfile(ROOT/'.tools/admob/android_source.zip',target)
print('Pinned isolated app export prepared',flush=True)
