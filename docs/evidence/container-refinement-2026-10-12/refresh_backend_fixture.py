from pathlib import Path
from types import SimpleNamespace
import json, sys
root=Path.cwd()
sys.path.insert(0,str(root/'backend'))
from bmt_backend.verifier import GodotVerifier
v=GodotVerifier(SimpleNamespace(godot_bin=r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',game_project=root/'game',verifier_timeout_seconds=90))
p=root/'backend/tests/fixtures/verified_oval.json'
data=json.loads(p.read_text())
old=data['expected_manifest']
new=v.validate_track(data['document'])
assert new['compiler_version']=='creator-compiler-27' and new['physics_version']=='arcade-planar-0.56'
# Existing authoring/input/timing data stay exact; this refresh pins only the manifest.
data['expected_manifest']=new
p.write_text(json.dumps(data,indent=2)+'\n')
variable=json.loads((root/'backend/tests/fixtures/variable_width_oval.json').read_text())
variable_manifest=v.validate_track(variable)
print(json.dumps({'previous':old,'current':new,'variable_width_hash':variable_manifest['track_content_hash']},indent=2))
