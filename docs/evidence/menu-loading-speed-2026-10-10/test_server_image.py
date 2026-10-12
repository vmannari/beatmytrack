"""Exercise the exact prepared image package against an owned local database."""
import base64
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
folder = Path(__file__).parent
docker = json.loads((ROOT / '.tools/gcp-staging/config.json').read_text())['docker']
tag = json.loads((ROOT / 'docs/evidence/menu-loading-speed-2026-10-10/server-image-proof.json').read_text())['local_image']
code = "import base64,json;from pathlib import Path;p=Path('/app/bmt_backend');print(json.dumps({str(f.relative_to(p)):base64.b64encode(f.read_bytes()).decode() for f in p.rglob('*') if f.is_file() and '__pycache__' not in f.parts}))"
result = subprocess.run([*docker,'run','--rm','--network=none','--entrypoint=python',tag,'-c',code],capture_output=True,text=True,timeout=30,check=True)
package = folder / 'exact-package/bmt_backend'
for name, encoded in json.loads(result.stdout).items():
    destination = package / name
    assert destination.resolve().is_relative_to(package.resolve())
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(base64.b64decode(encoded))
runner = (folder / 'owned_pg_final.py').read_text()
runner = runner.replace("'PYTHONPATH':str(ROOT/'backend')", "'PYTHONPATH':str(ROOT/'build/menu-speed/exact-package')")
runner = runner.replace("'backend/tests/test_domains.py',", "'backend/tests/test_domains.py',")
probe = (folder / 'backend_probe.py').read_text()
probe = probe.replace("sys.path.insert(0,str(ROOT/'backend'))", "sys.path.insert(0,str(ROOT/'build/menu-speed/exact-package'))")
(folder / 'backend_probe.py').write_text(probe)
(folder / 'owned_pg_image.py').write_text(runner)
subprocess.run([sys.executable,str(folder / 'owned_pg_image.py')],env={**os.environ,'PYTHONPATH':str(folder / 'exact-package')},check=True)
