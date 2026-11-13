"""Build from the accepted immutable snapshot, preserving concurrent work."""
import json
import os
from pathlib import Path
import shutil
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
EVIDENCE = ROOT / 'docs/evidence/tablet-loading-deploy-2026-11-07'
BASE = Path(json.loads((ROOT/'docs/evidence/loading-half-2026-11-06/accepted-project.json').read_text())['project'])
source = (ROOT/'docs/evidence/loading-half-2026-11-06/freeze_project.py').read_text()
source = source.replace('evidence = Path(__file__).resolve().parent', 'evidence = EVIDENCE')
source = source.replace("owned = root/'build/loading-half-20261106'/('frozen-'+str(time.time_ns()))", "owned = OUT/'isolated-accepted'")
source = source.replace("for name in ('docs','native'):", "for name in ('docs',):")
for old, new in [("root/'game/.godot/imported'", "BASE/'.godot/imported'"),
                 ("root/'game/.godot'", "BASE/'.godot'"),
                 ("root/'game/assets'", "BASE/'assets'"), ("root/'game'", 'BASE')]:
    source = source.replace(old, new)
exec(compile(source, 'freeze_project.py', 'exec'), globals())
for name in ['scripts', 'native', 'backend']:
    assert (owned/name).resolve().is_relative_to(owned.resolve())
    shutil.copytree(ROOT/name, owned/name, dirs_exist_ok=True, ignore=shutil.ignore_patterns('__pycache__', '.pytest_cache', '.ruff_cache'))
for name in ['.gitignore', '.gitattributes', 'godot-version.txt']:
    shutil.copyfile(ROOT/name, owned/name)
destination = owned/'.tools/admob/android_source.zip'
destination.parent.mkdir(parents=True)
shutil.copyfile(ROOT/'.tools/admob/android_source.zip', destination)
env = {**os.environ, 'GIT_OPTIONAL_LOCKS': '0'}
subprocess.run(['git', 'init', '--quiet', str(owned)], check=True, env=env)
print('Isolated accepted source prepared: '+str(owned), flush=True)
