"""Publish staged door resources with task-start byte copies and atomic writes."""
import hashlib
import json
import os
import sys
from run_volt_front_door import ROOT, OUT, WORK


def digest(data):
    return hashlib.sha256(data).hexdigest()


def publish(kind):
    staged = json.loads((OUT / (kind + '-staged.json')).read_text())
    publication = OUT / 'publication.json'
    result = json.loads(publication.read_text()) if publication.exists() else {'files': {}}
    task_start = json.loads((OUT / 'before-sources.json').read_text())
    for name, relative in staged['files'].items():
        target = ROOT / relative
        before = target.read_bytes() if target.exists() else None
        backup = WORK / 'before' / relative
        if relative in task_start and before is not None and not backup.exists():
            backup.parent.mkdir(parents=True, exist_ok=True)
            backup.write_bytes(before)
        after = (WORK / 'staged' / name).read_bytes()
        temporary = target.with_name(target.name + '.tmp')
        temporary.write_bytes(after)
        os.replace(temporary, target)
        result['files'][relative] = {
            'before': task_start.get(relative),
            'after': digest(after),
        }
    for relative in ['game/vehicle/electric_reference_' + name + '.gd' for name in ('body', 'cabin', 'details')]:
        result['files'][relative] = {
            'before': digest((WORK / 'before' / relative).read_bytes()),
            'after': digest((ROOT / relative).read_bytes()),
        }
    publication.write_text(json.dumps(result, indent=2) + '\n')
    print('VFD_PUBLICATION', kind, len(staged['files']))


if __name__ == '__main__':
    publish(sys.argv[1])
