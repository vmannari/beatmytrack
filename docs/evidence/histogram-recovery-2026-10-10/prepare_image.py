"""Offline local lap-PB overlay, preserving the exact development parent."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
FOLDER=Path(__file__).parent
context=FOLDER/'server-image';context.mkdir(exist_ok=True)
docker=json.loads((ROOT/'.tools/gcp-staging/config.json').read_text())['docker']
parent=json.loads((FOLDER/'live-baseline.json').read_text())['api_image']
expected_parent='sha256:d16a4a17e3cb64db4d1d654c818f2076a3b633399ede76a19f75d563987d872d'
assert parent.endswith('@'+expected_parent), 'Live parent changed; rebase before packaging'
tag='bmt-lap-recovery:20261010'

def command(*args):
    r=subprocess.run([*docker,*args],capture_output=True,text=True,timeout=180)
    if r.returncode:
        (context/'last-command.log').write_text(r.stdout+r.stderr)
        raise RuntimeError('Offline local image operation failed: '+args[0])
    return r.stdout

code="import json;from pathlib import Path;p=Path('/app/bmt_backend');print(json.dumps({str(f.relative_to(p)):f.read_text() for f in p.rglob('*.py')}))"
base=json.loads(command('run','--rm','--network=none','--entrypoint=python',expected_parent,'-c',code))
(context/'base-modules.json').write_text(json.dumps(base))
changed={};overlay=context/'overlay';overlay.mkdir(exist_ok=True)

def local(n):return (ROOT/'backend/bmt_backend'/n).read_text()
def function(source,n):
    node=next(v for v in ast.parse(source).body if isinstance(v,(ast.FunctionDef,ast.ClassDef)) and v.name==n)
    first=min([node.lineno]+[d.lineno for d in node.decorator_list])-1
    return '\n'.join(source.splitlines()[first:node.end_lineno])
def replace_once(s,a,b):
    assert s.count(a)==1,a[:100]
    return s.replace(a,b)
def save(n,s):
    compile(s,n,'exec');p=overlay/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8')
    changed[n]=hashlib.sha256(p.read_bytes()).hexdigest()

source=replace_once(base['runs.py'],function(base['runs.py'],'best_lap_times'),function(local('runs.py'),'best_lap_times'))
# Preserve every other route/helper and their existing source order.
save('runs.py',source)
source=base['track_models.py']
old='    __table_args__ = (Index("ix_run_claim", "status", "lease_until", "created_at"),)'
source=replace_once(source,old,'    __table_args__ = (Index("ix_run_claim", "status", "lease_until", "created_at"),\n'
    '                      Index("ix_run_board_player_id", "board_id", "player_id", "id"),\n'
    '                      Index("ix_run_board_id", "board_id", "id"))')
for name in ('LapPersonalBest','LapBestState'):source+='\n\n'+function(local('track_models.py'),name)+'\n'
save('track_models.py',source)
source=replace_once(base['worker.py'],'            if refresh_histograms:\n',
    '            if refresh_histograms:\n                from .lap_bests import backfill_one\n'
    '                if backfill_one(app.state.session_factory)["worked"]:\n                    return True\n')
save('worker.py',source)

source=replace_once(base['test_population_batch.py'],function(base['test_population_batch.py'],'create_batch'),function(local('test_population_batch.py'),'create_batch'))
source=replace_once(source,'from .track_models import Board, OperationState, PersonalBest, Run, Track, TrackVersion, digest, now',
    'from .track_models import Board, LapBestState, OperationState, PersonalBest, Run, Track, TrackVersion, digest, now')
save('test_population_batch.py',source)

for n in ('histogram_snapshots.py','maintenance.py'):
    assert base[n]==(ROOT/'build/lap-pb-2026-10-10/before/backend/bmt_backend'/n).read_text(),n
    save(n,local(n))
for n in ('lap_bests.py','migrations/versions/0024_lap_personal_bests.py'):
    assert n not in base;save(n,local(n))
patch='''import hashlib,json,shutil,sys
from pathlib import Path
def hashes(p):return {str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for f in p.rglob('*') if f.is_file() and '__pycache__' not in f.parts and '.godot' not in f.parts}
game=Path('/opt/bmt');backend=Path('/app/bmt_backend');canonical=hashes(game);before=hashes(backend)
expected=json.loads(Path('/tmp/lap-pb/expected.json').read_text())
for name,digest in expected.items():
 p=Path('/tmp/lap-pb/overlay')/name;assert hashlib.sha256(p.read_bytes()).hexdigest()==digest
 target=backend/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
after=hashes(backend);changed=sorted(n for n,h in after.items() if before.get(n)!=h)
assert changed==sorted(expected);assert hashes(game)==canonical
sys.path.insert(0,'/app')
from bmt_backend.app import create_app
from bmt_backend.cloud_smoke import check_comparison_route
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade,SCHEMA_HEAD
assert SCHEMA_HEAD=='0024_lap_personal_bests'
app=create_app(Settings(environment='test',database_url='sqlite://'))
upgrade(app.state.engine);check_comparison_route(app)
app.state.engine.dispose();app.state.verifier.close()
Path('/app/lap-pb-proof.json').write_text(json.dumps({'changed_backend_files':changed,'canonical_files':len(canonical),'canonical_unchanged':True,'game_hashes':canonical,'schema_head':SCHEMA_HEAD,'comparison_route':True}))
print('LAP_PB_OVERLAY_VALID')
'''
(context/'patch.py').write_text(patch)
(context/'expected.json').write_text(json.dumps(changed))
# Use an already present local tag after verifying its immutable image ID.
assert json.loads(command('image','inspect','bmt-menu-read:20261010'))[0]['Id']==expected_parent
(context/'Dockerfile').write_text('FROM bmt-menu-read:20261010\nUSER root\nCOPY overlay /tmp/lap-pb/overlay\n'
    'COPY patch.py expected.json /tmp/lap-pb/\nRUN python /tmp/lap-pb/patch.py\nUSER 10001:10001\n')
build_context=str(context.resolve())
if any('wsl' in item.lower() for item in docker):build_context='/mnt/'+context.resolve().drive[0].lower()+str(context.resolve())[2:].replace('\\','/')
(FOLDER/'image-build.log').write_text(command('build','--pull=false','--network=none','-t',tag,build_context))
proof=json.loads(command('run','--rm','--network=none','--entrypoint=cat',tag,'/app/lap-pb-proof.json'))
proof.update(parent=parent,local_image=tag,image_id=json.loads(command('image','inspect',tag))[0]['Id'],published=False,deployed=False)
(FOLDER/'image-proof.json').write_text(json.dumps(proof,indent=2))
print(json.dumps({k:v for k,v in proof.items() if k!='game_hashes'},indent=2))
