"""Supplement known-format scan with literal token/credential fields, never values."""
import collections
import json
import math
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
pattern = re.compile(r'''(?i)["']?(access_token|refresh_token|admin_owner_key|admin_analyst_key|dev_auth_key|client_secret|password)["']?\s*[:=]\s*["']([A-Za-z0-9_+/=-]{32,150})["']''')
found, files = [], 0
names = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
for name in names:
    p = ROOT / name
    if not name or not p.is_file() or p.suffix.lower() not in ('.py', '.gd', '.json', '.log', '.txt', '.cfg', '.env', '.patch', '.diff', '.xml', '.md', '.ps1', '.yaml', '.yml', '.js') or p.stat().st_size > 2_000_000:
        continue
    files += 1
    for number, line in enumerate(p.read_text(encoding='utf-8', errors='replace').splitlines(), 1):
        for match in pattern.finditer(line):
            value = match[2]
            counts = collections.Counter(value)
            entropy = -sum(n / len(value) * math.log2(n / len(value)) for n in counts.values())
            if entropy >= 3.5:
                found.append({'path': name, 'line': number, 'field': match[1], 'length': len(value)})
result = {'scope': 'current tracked text files <=2MB; literal credential fields with entropy >=3.5; no values emitted',
          'files': files, 'candidates': found}
(OUT / 'literal-token-scan.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
