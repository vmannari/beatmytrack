"""Verify the extraction retains every translatable message and plural."""
import importlib.util
import json
from pathlib import Path
import sys
from unittest.mock import patch

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
sys.path.insert(0,str(root/'scripts'))
spec = importlib.util.spec_from_file_location('shell_localization',root/'scripts/localization.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
read_text = Path.read_text
sources = module.sources
def before_read(path,*args,**kwargs):
    if path == root/'game/core/app.gd': return read_text(evidence/'before/game/core/app.gd',*args,**kwargs)
    return read_text(path,*args,**kwargs)
with patch.object(module,'sources',lambda:[p for p in sources() if '/core/features/' not in p.as_posix()]):
    with patch.object(Path,'read_text',before_read): before = module.collect()
after = module.collect()
missing = sorted(before.keys()-after.keys())
changed = [key for key in before.keys() & after.keys() if before[key]['plural'] != after[key]['plural']]
report = dict(before_messages=len(before),after_messages=len(after),missing=missing,changed_plurals=changed,
              added=sorted(after.keys()-before.keys()))
(evidence/'copy.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2,ensure_ascii=False))
assert not missing and not changed
