"""Exercise the exact prepared package; no remote services or image changes."""
import base64
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2];folder=Path(__file__).parent
docker=json.loads((ROOT/'.tools/gcp-staging/config.json').read_text())['docker']
proof=json.loads((folder/'image-proof.json').read_text());tag=proof['local_image']
code="import base64,json;from pathlib import Path;p=Path('/app/bmt_backend');print(json.dumps({str(f.relative_to(p)):base64.b64encode(f.read_bytes()).decode() for f in p.rglob('*') if f.is_file() and '__pycache__' not in f.parts}))"
r=subprocess.run([*docker,'run','--rm','--network=none','--entrypoint=python',tag,'-c',code],capture_output=True,text=True,timeout=30,check=True)
package=folder/'exact-package/bmt_backend'
for name,data in json.loads(r.stdout).items():
    target=package/name;assert target.resolve().is_relative_to(package.resolve())
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(base64.b64decode(data))
env={**os.environ,'PYTHONPATH':str(folder/'exact-package'),'PYTHONUTF8':'1'}
args=[sys.executable,'-m','pytest','backend/tests/test_histogram_recovery.py','backend/tests/test_lap_bests.py','backend/tests/test_histogram_snapshots.py',
      'backend/tests/test_domains.py','backend/tests/test_test_drivers.py','-k',
      'not postgres and (lap_bests or histogram or comparison)','-m','not godot','-q','--tb=short',
      '--junitxml='+str(folder/'image-sqlite-tests.xml')]
r=subprocess.run(args,env=env,capture_output=True,text=True,timeout=160,check=False)
(folder/'image-sqlite-tests.log').write_text(r.stdout+r.stderr,encoding='utf-8');print(r.stdout[-6000:],flush=True)
if r.returncode:raise RuntimeError('Exact-image SQLite checks failed')
runner=(folder/'owned_postgres.py').read_text()
runner=runner.replace("'PYTHONPATH':str(ROOT/'backend')","'PYTHONPATH':str(ROOT/'build/histogram-recovery-2026-10-10/exact-package')")
start=runner.index('    tests=subprocess.run(');end=runner.index('\nfinally:',start)
runner=runner[:start]+'''    tests=subprocess.run([sys.executable,'-m','pytest','backend/tests/test_histogram_recovery.py','backend/tests/test_histogram_recovery.py','backend/tests/test_lap_bests.py','backend/tests/test_histogram_snapshots.py','-k','postgres and not sqlite','-q','--tb=short','--junitxml='+str(Path(__file__).with_name('image-postgres-tests.xml'))],env=env,capture_output=True,text=True,timeout=180,check=False)
    Path(__file__).with_name('image-postgres-tests.log').write_text(tests.stdout+tests.stderr,encoding='utf-8')
    print(tests.stdout[-5000:],flush=True)
    if tests.returncode:raise RuntimeError('Exact-image PostgreSQL checks failed')
'''+runner[end:]
(folder/'owned_image_postgres.py').write_text(runner)
subprocess.run([sys.executable,str(folder/'owned_image_postgres.py')],env=env,check=True)
