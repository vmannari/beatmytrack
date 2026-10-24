"""Query public OSV with package names/versions only; no source or credentials."""
import json
from pathlib import Path
import requests

HERE = Path(__file__).resolve().parent
packages = json.loads((HERE / 'dependencies.json').read_text())['locked']
queries = [{'package': {'name': name, 'ecosystem': 'PyPI'}, 'version': version}
           for name, version in packages.items()]
result = {'provider': 'https://api.osv.dev/v1/querybatch', 'packages': len(packages)}
try:
    response = requests.post(result['provider'], json={'queries': queries}, timeout=(5, 25))
    response.raise_for_status()
    rows = response.json()['results']
    if len(rows) != len(queries):
        raise ValueError('Incomplete advisory response')
    result['status'] = 'complete'
    result['matches'] = [{'package': name, 'version': packages[name], 'advisories': row.get('vulns', [])}
                         for name, row in zip(packages, rows, strict=True) if row.get('vulns')]
except (requests.RequestException, ValueError, KeyError) as error:
    result.update(status='unavailable', error_type=type(error).__name__)
(HERE / 'dependency-audit.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
