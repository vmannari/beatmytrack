"""Extract code only from the exact live API image using an isolated container."""
import io
import json
from pathlib import Path
import subprocess
import tarfile

WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
inspection=json.loads((WORK/'inspection.json').read_text())
image=next(x['image'] for x in inspection if x['kind']=='api' and x['name'].endswith('-api'))
assert image.startswith('europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/') and '@sha256:' in image
destination=WORK/'baseline'
assert not destination.exists(), 'Refusing to replace an extracted baseline'
program="import sys,tarfile;t=tarfile.open(fileobj=sys.stdout.buffer,mode='w|');t.add('/app/bmt_backend',arcname='bmt_backend');t.add('/app/requirements.lock',arcname='requirements.lock');t.close()"
command=['wsl.exe','-d','Ubuntu','--','docker','run','--rm','--network=none','--entrypoint=python',image,'-c',program]
result=subprocess.run(command,capture_output=True,timeout=120)
if result.returncode:
 (WORK/'extract-error.private.log').write_bytes(result.stderr)
 raise RuntimeError('Code extraction failed; private diagnostic retained')
destination.mkdir()
with tarfile.open(fileobj=io.BytesIO(result.stdout)) as archive:
 members=archive.getmembers()
 for member in members:
  target=(destination/member.name).resolve()
  assert target.is_relative_to(destination.resolve()) and (member.isfile() or member.isdir())
 archive.extractall(destination,members=members)
print(json.dumps({'source_image':image,'code_files':len(list(destination.rglob('*'))),'production_data_copied':False}))
