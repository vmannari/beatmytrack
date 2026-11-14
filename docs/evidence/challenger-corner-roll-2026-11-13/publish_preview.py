"""Render privately and validate before replacing the requested catalogue image.

This task does not use the known render-before-validation publication path in
the production preview baker. Five other photographs stay byte-exact.
"""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-corner-roll-2026-11-13'
STAGE=BUILD/'preview-staging'
LIVE=ROOT/'game/assets/garage/previews_v1'
STAGE.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
names=['provenance.json',*['%s.png'%v for v in ['compact','kart','forklift','electric','hovercraft','super_rally']]]
snapshot={name:sha(LIVE/name) for name in names}
for name in names:shutil.copy2(LIVE/name,STAGE/name)
production=ROOT/'scripts/bake_garage_previews.gd'
source=production.read_text()
old='ProjectSettings.globalize_path("res://assets/garage/previews_v1")'
new='ProjectSettings.globalize_path("res://../build/challenger-corner-roll-2026-11-13/preview-staging")'
assert source.count(old)==1
private=BUILD/'bake_private_preview.gd'
private.write_text(source.replace(old,new))
command=[sys.executable,str(ROOT/'scripts/run_no_crash_dialog.py'),'--',
         'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe',
         '--path',str(ROOT/'game'),'--audio-driver','Dummy','--rendering-method','gl_compatibility',
         '--script','res://../build/challenger-corner-roll-2026-11-13/bake_private_preview.gd',
         '--',*['--exclude-vehicle='+v for v in ['compact','kart','forklift','electric','hovercraft']]]
with (OUT/'private-preview.log').open('w',encoding='utf-8') as log:
    result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=300)
assert result.returncode==0,result.returncode
assert 'SCRIPT ERROR:' not in (OUT/'private-preview.log').read_text()
# Run the production validator with only its output-folder constant changed.
# __file__ stays at the production location, preserving every source/root check.
checker=ROOT/'scripts/check_garage_previews.py'
code=checker.read_text();old='folder = ROOT / "game/assets/garage/previews_v1"'
assert code.count(old)==1
code=code.replace(old,'folder = ROOT / "build/challenger-corner-roll-2026-11-13/preview-staging"')
namespace={'__name__':'task_private_preview_validation','__file__':str(checker)}
exec(compile(code,str(checker), 'exec'),namespace)
namespace['check']()
assert {name:sha(LIVE/name) for name in names}==snapshot,'Concurrent live preview change; nothing published'
protected=[name for name in names if name not in ['super_rally.png','provenance.json']]
assert all(sha(STAGE/name)==snapshot[name] for name in protected)
namespace['check']()
for name in ['super_rally.png','provenance.json']:
    target=(LIVE/name).resolve();staged=(STAGE/name).resolve()
    assert target.parent==LIVE.resolve() and staged.parent==STAGE.resolve()
    os.replace(staged,target)
assert all(sha(LIVE/name)==snapshot[name] for name in protected)
(OUT/'preview-publication.json').write_text(json.dumps({
    'command':command,'exit_code':result.returncode,'baker_sha256':sha(production),'validator_sha256':sha(checker),
    'validated_before_publication':True,'live_snapshot_unchanged_before_publication':True,
    'protected_pngs_exact':protected,'before':snapshot,'after':{name:sha(LIVE/name) for name in names},
},indent=2))
print('PRIVATE_PREVIEW_PUBLICATION: validated native Super rally image; five photographs exact')
