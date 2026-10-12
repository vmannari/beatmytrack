import importlib.util
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('studio_rollout', root / '.tools/backend_studio_rollout_20261011.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
kind, name = ('job', m.service.n[sys.argv[1]]) if len(sys.argv) > 1 else ('api', m.service.n['api'])
old = json.loads((m.CONTEXT.parent / ('before-' + name + '.private.json')).read_text())
current = m.service.describe(kind, name)
(m.CONTEXT.parent / (name + '-current.private.json')).write_text(json.dumps(current))


def diff(a, b, path=''):
    if isinstance(a, dict) and isinstance(b, dict):
        return sum((diff(a.get(k), b.get(k), path + '/' + k) for k in sorted(set(a) | set(b))), [])
    if isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
        return sum((diff(x, y, path + '/' + str(i)) for i, (x, y) in enumerate(zip(a, b))), [])
    return [] if a == b else [path]


print('Changed template paths:', diff(m.normalized_template(old), m.normalized_template(current)))
print('Changed resource label paths:', diff(old.get('metadata', {}).get('labels'), current.get('metadata', {}).get('labels')))
if kind == 'api':
    before_traffic = {(v['revisionName'], v.get('percent', 0)) for v in old['status']['traffic'] if v.get('percent', 0)}
    after_traffic = {(v['revisionName'], v.get('percent', 0)) for v in current['status']['traffic'] if v.get('percent', 0)}
    print('Original normal traffic preserved:', before_traffic == after_traffic)
