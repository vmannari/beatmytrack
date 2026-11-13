"""Use the existing immutable task-start project plus only graphics changes."""
from pathlib import Path
import json
import shutil

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
BASE = ROOT/'build/loading-half-20261106/frozen-1793996701250524100/game'
assert BASE.is_dir()
source = (OUT.parent/'freeze_project.py').read_text(encoding='utf-8')
source = source.replace("evidence = Path(__file__).resolve().parent", "evidence = OUT")
source = source.replace("root = evidence.parents[2]", "root = ROOT")
for old, new in [
    ("root/'game/.godot/imported'", "BASE/'.godot/imported'"),
    ("root/'game/.godot'", "BASE/'.godot'"),
    ("root/'game/assets'", "BASE/'assets'"),
    ("root/'game'", "BASE"),
]:
    source = source.replace(old,new)
exec(compile(source,str(OUT.parent/'freeze_project.py'),'exec'),globals())
CHANGED = [
    'ui/rivalry_cached_podium.gd','ui/rivalry_podium_pictures.gd',
    'ui/rivalry_victory_car.gd','ui/weekly_rivalry_page.gd','ui/player_profile.gd',
    'tests/test_rivalry_podium_pictures.gd','tests/test_rivalry_podium_picture_storage.gd',
    'tests/profile_loading_half.gd',
]
for relative in CHANGED:
    shutil.copyfile(ROOT/'game'/relative,game/relative)
(OUT/'candidate.json').write_text(json.dumps({'project':str(game),'base':str(BASE),'overlay':CHANGED},indent=2)+'\n')
