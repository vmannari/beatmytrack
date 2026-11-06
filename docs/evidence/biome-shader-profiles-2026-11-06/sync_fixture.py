"""Update only this task's files in its owned fixture, between test runs."""
from pathlib import Path
import json,shutil
p=Path(__file__).resolve().parent; root=p.parents[2]
project=Path(json.loads((p/'frozen-project.json').read_text())['project'])
assert project.resolve().is_relative_to((root/'build/biome-shader-profiles-20261106').resolve())
names=['core/game.gd','core/features/race.gd','backend/product_telemetry.gd','backend/backend_client.gd',
       'backend/shader_profile_telemetry.gd','rendering/biome_shader_profile.gd',
       'tests/test_biome_shader_profiles.gd','tests/profile_biome_shader_profiles.gd']
for name in names: shutil.copyfile(root/'game'/name,project/name)
print('Updated',len(names),'owned fixture sources')
