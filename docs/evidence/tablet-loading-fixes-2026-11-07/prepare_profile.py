"""Reuse the qualified local-only observer against the accepted candidate."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'build/tablet-loading-fixes-20261107'
qualified = '--qualified' in sys.argv
EVIDENCE = Path(__file__).resolve().parent/('tablet-qualified' if qualified else 'tablet')
EVIDENCE.mkdir(exist_ok=True)
BASE_ROOT = OUT/('qualified' if qualified else 'candidate')
BASE = BASE_ROOT/'game'
owned = OUT/('profiled-qualified' if qualified else 'profiled')
game = owned/'game'
assert not owned.exists()
game.mkdir(parents=True)

def junction(source, destination):
    assert destination.absolute().is_relative_to(owned.absolute())
    quote = lambda p: "'"+str(p).replace("'","''")+"'"
    subprocess.run(['powershell','-NoProfile','-Command',
        'New-Item -ItemType Junction -Path '+quote(destination)+' -Target '+quote(source)+' | Out-Null'],check=True)

for item in BASE.iterdir():
    if item.name in ('.godot','android','assets'): continue
    if item.is_dir(): shutil.copytree(item,game/item.name)
    else: shutil.copyfile(item,game/item.name)
for name in ('assets',): junction(BASE/name,game/name)
(game/'.godot').mkdir()
for name in ('global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg'):
    if (BASE/'.godot'/name).exists(): shutil.copyfile(BASE/'.godot'/name,game/'.godot'/name)
junction(BASE/'.godot/imported',game/'.godot/imported')
shutil.copytree(BASE_ROOT/'scripts',owned/'scripts')
for name in ('godot-version.txt','.gitattributes','.gitignore'): shutil.copyfile(BASE_ROOT/name,owned/name)
for name in ('native','backend','docs','.tools'): junction(BASE_ROOT/name,owned/name)
prior = ROOT/'docs/evidence/tablet-phase-profile-2026-11-07'
for name in ('tablet_phase_trace.gd','tablet_phase_probe.gd'):
    text = (prior/name).read_text().replace('tablet-phase-20261107','tablet-loading-fixes-20261107')
    (EVIDENCE/name).write_text(text,newline='\n')
source = (prior/'prepare.py').read_text()
source = source[source.index('before = {}'):]
exec(compile(source,'qualified-observer-overlay.py','exec'),globals())
for name in ('core/build_identity.gd','project.godot'):
    shutil.copyfile(BASE/name,game/name)
subprocess.run(['git','init','--quiet',str(owned)],check=True)
print('Task-owned profiling overlay prepared; original candidate untouched')
