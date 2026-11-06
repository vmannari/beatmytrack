"""Copy explicitly named task-owned fixes into the owned frozen test project."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
receipt_path = evidence/'frozen-project.json'
receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
project = Path(receipt['project'])
assert project.resolve().is_relative_to((root/'build/startup-shell-20261104').resolve())
updates = []
for relative in sys.argv[1:]:
    source = (root/'game'/relative).resolve()
    target = (project/relative).resolve()
    assert source.is_relative_to((root/'game').resolve())
    assert target.is_relative_to(project.resolve())
    key = 'game/'+relative.replace('\\','/')
    before = hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None
    shutil.copyfile(source,target)
    after = hashlib.sha256(target.read_bytes()).hexdigest()
    receipt['copied_sha256'][key] = after
    updates.append(dict(path=key,before=before,after=after))
receipt.setdefault('task_updates',[]).extend(updates)
receipt_path.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps(updates,indent=2))
