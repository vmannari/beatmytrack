"""Serial frozen A/B startup probes followed by native/lifecycle regressions."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PROJECT = Path(json.loads((OUT/'frozen-project.json').read_text())['project'])
RUNTIME = ['game/core/app.gd','game/ui/header_car_appearance_cache.gd','game/ui/profile_car.gd']
TESTS = ['game/tests/profile_deferred_header.gd','game/tests/test_deferred_header.gd']

def variant(name):
    for relative in RUNTIME:
        shutil.copyfile(OUT/name/relative, PROJECT.parent/relative)

def run(name, script, *options):
    subprocess.run([sys.executable,str(OUT/'run_case.py'),name,script,'--project',str(PROJECT),*options],check=True)

for relative in RUNTIME+TESTS:
    source = ROOT/relative
    destination = OUT/'after'/relative
    destination.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,destination)
    shutil.copyfile(source,PROJECT.parent/relative)
(OUT/'candidate-sha256.json').write_text(json.dumps({p:hashlib.sha256((OUT/'after'/p).read_bytes()).hexdigest() for p in RUNTIME+TESTS},indent=2)+'\n')
try:
    variant('before')
    run('frozen-before-custom-1','profile_deferred_header.gd','--native')
    variant('after')
    run('frozen-after-custom-1','profile_deferred_header.gd','--native')
    run('frozen-after-custom-2','profile_deferred_header.gd','--native')
    variant('before')
    run('frozen-before-custom-2','profile_deferred_header.gd','--native')
    run('frozen-before-stock','profile_deferred_header.gd','--native','--args','--stock')
    variant('after')
    run('frozen-after-stock','profile_deferred_header.gd','--native','--args','--stock')
    # Read the baseline-produced exact-key PNG in a separate candidate process.
    run('frozen-after-disk-hit','profile_deferred_header.gd','--native','--profile','frozen-before-custom-1')
    run('frozen-contract-headless','test_deferred_header.gd')
    run('frozen-contract-compatibility','test_deferred_header.gd','--native','--args','--garage')
    run('frozen-contract-mobile','test_deferred_header.gd','--native','--renderer','mobile','--args','--garage')
    run('frozen-shell','test_startup_shell.gd','--native')
    run('frozen-header-compatibility','test_shared_graphics_header.gd','--native')
    run('frozen-header-mobile','test_shared_graphics_header.gd','--native','--renderer','mobile')
finally:
    variant('after')
