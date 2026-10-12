"""Build a local histogram-only overlay of the observed development image."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
context = Path(__file__).with_name('server-image')
evidence = ROOT / 'docs/evidence/menu-loading-speed-2026-10-10'
config = json.loads((ROOT / '.tools/gcp-staging/config.json').read_text())
docker = config['docker']
parent = json.loads((evidence / 'live-latency.json').read_text())['image']
assert '@sha256:' in parent and 'beat-my-track/' in parent
context.mkdir(exist_ok=True)

def command(*args):
    result = subprocess.run([*docker, *args], capture_output=True, text=True, timeout=180)
    if result.returncode:
        (context / 'last-command.log').write_text(result.stdout+result.stderr)
        raise RuntimeError('Local image operation failed: ' + args[0])
    return result.stdout

code = "import json;from pathlib import Path;p=Path('/app/bmt_backend');print(json.dumps({str(f.relative_to(p)):f.read_text() for f in p.rglob('*.py')}))"
base = json.loads(command('run', '--rm', '--network=none', '--entrypoint=python', parent, '-c', code))
(context / 'base-modules.json').write_text(json.dumps(base))
overlay = context / 'overlay'
overlay.mkdir(exist_ok=True)
changed = {}

def local(name):
    return (ROOT / 'backend/bmt_backend' / name).read_text(encoding='utf-8')

def function(source, name):
    node = next(n for n in ast.parse(source).body if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and n.name == name)
    first = min([node.lineno] + [d.lineno for d in node.decorator_list]) - 1
    return '\n'.join(source.splitlines()[first:node.end_lineno])

def replace_once(source, before, after):
    assert source.count(before) == 1, before[:100]
    return source.replace(before, after)

def save(name, source):
    compile(source, name, 'exec')
    if base.get(name) == source:
        return
    path = overlay / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding='utf-8')
    changed[name] = hashlib.sha256(path.read_bytes()).hexdigest()

# Route replacements use the tested stored populations. Existing uploads,
# ticket handling, leaderboard/scoring and all other functions stay exact.
source = base['runs.py']
for name in ('histogram', 'results_comparison'):
    source = replace_once(source, function(source, name), function(local('runs.py'), name))
source = replace_once(source, 'from .board_cache import cached', 'from .board_cache import cached\nfrom .histogram_population import HistogramPopulation')
for name in ('comparison_populations', 'population_comparison'):
    source += '\n\n' + function(local('runs.py'), name) + '\n'
save('runs.py', source)
for name in ('board_cache.py', 'histogram_population.py', 'histogram_snapshots.py'):
    save(name, local(name))

source = base['track_models.py']
source = replace_once(source, function(source, 'Board'), function(local('track_models.py'), 'Board'))
source += '\n\n' + function(local('track_models.py'), 'HistogramSnapshot') + '\n'
save('track_models.py', source)

source = base['config.py']
source = replace_once(source, '    retention_days: int = 90', '    histogram_refresh_seconds: int = 900\n    retention_days: int = 90')
source = replace_once(source, '            "verifier_timeout_seconds",', '            "histogram_refresh_seconds",\n            "verifier_timeout_seconds",')
save('config.py', source)

source = base['worker.py']
source = replace_once(source, 'def process_one(app) -> bool:', 'def process_one(app, *, refresh_histograms=False) -> bool:')
before = '            from .test_population_batch import drive_idle as drive_batch'
after = '            if refresh_histograms:\n                from .histogram_snapshots import refresh_one as refresh_histogram\n                if refresh_histogram(app):\n                    return True\n' + before
source = replace_once(source, before, after)
source = replace_once(source, '    run_worker(app, process_one, once=args.once)', '    run_worker(app, process_worker_job, once=args.once)')
source = replace_once(source, 'def main() -> None:', function(local('worker.py'), 'process_worker_job') + '\n\n\ndef main() -> None:')
save('worker.py', source)

# 0021 is the existing predecessor. Its nullable/unlimited defaults preserve
# prior challenges. No new challenge behavior is included in this image.
for name in ('migrations/versions/0021_challenge_attempts.py', 'migrations/versions/0022_histogram_cache.py', 'migrations/versions/0023_operational_read_indexes.py'):
    assert name not in base
    save(name, local(name))

patch = '''import hashlib,json,shutil,sys
from pathlib import Path
def hashes(folder):
 return {str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts and '.godot' not in p.parts}
game=Path('/opt/bmt');backend=Path('/app/bmt_backend')
canonical=hashes(game);before=hashes(backend)
overlay=Path('/tmp/menu-read/overlay')
expected=json.loads(Path('/tmp/menu-read/expected.json').read_text())
for name,digest in expected.items():
 p=overlay/name;assert hashlib.sha256(p.read_bytes()).hexdigest()==digest
 destination=backend/name;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,destination)
after=hashes(backend)
changed=sorted(name for name,digest in after.items() if before.get(name)!=digest)
assert changed==sorted(expected),(changed,sorted(expected))
assert hashes(game)==canonical
sys.path.insert(0,'/app')
from bmt_backend.app import create_app
from bmt_backend.cloud_smoke import check_comparison_route
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade,SCHEMA_HEAD
assert SCHEMA_HEAD=='0023_operational_read_indexes',SCHEMA_HEAD
app=create_app(Settings(environment='test',database_url='sqlite://'))
upgrade(app.state.engine)
check_comparison_route(app)
app.state.engine.dispose();app.state.verifier.close()
Path('/app/menu-read-proof.json').write_text(json.dumps({'changed_backend_files':changed,'canonical_unchanged':True,'canonical_files':len(canonical),'game_hashes':canonical,'schema_head':SCHEMA_HEAD,'comparison_route':True}))
print('MENU_READ_OVERLAY_VALID')
'''
(context / 'patch.py').write_text(patch)
(context / 'expected.json').write_text(json.dumps(changed))
(context / 'Dockerfile').write_text('FROM ' + parent + '\nUSER root\nCOPY overlay /tmp/menu-read/overlay\nCOPY patch.py expected.json /tmp/menu-read/\nRUN python /tmp/menu-read/patch.py\nUSER 10001:10001\n')
tag = 'bmt-menu-read:20261010'
build_context = str(context)
if any('wsl' in item.lower() for item in docker):
    build_context = '/mnt/' + context.drive[0].lower() + str(context)[2:].replace('\\','/')
output = command('build', '--pull=false', '--network=none', '-t', tag, build_context)
(evidence / 'server-image-build.log').write_text(output)
proof = json.loads(command('run', '--rm', '--network=none', '--entrypoint=cat', tag, '/app/menu-read-proof.json'))
proof['parent'] = parent
proof['local_image'] = tag
proof['image_id'] = json.loads(command('image', 'inspect', tag))[0]['Id']
proof['deployed'] = False
proof['published'] = False
(evidence / 'server-image-proof.json').write_text(json.dumps(proof, indent=2) + '\n')
print(json.dumps({key:value for key,value in proof.items() if key != 'game_hashes'},indent=2))
