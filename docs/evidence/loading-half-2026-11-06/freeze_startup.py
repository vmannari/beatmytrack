"""Freeze task baseline plus only startup/audio changes for controlled checks."""
import hashlib
import json
from pathlib import Path
import shutil

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
baseline = Path(json.loads((evidence/'baseline-project.json').read_text())['project'])
freezer = evidence/'freeze_project.py'
code = freezer.read_text(encoding='utf-8')
code = code.replace("root/'game'", 'baseline_source').replace("root/'game/", "baseline_source/'")
code = code.replace("evidence/'frozen-project.json'", "evidence/'startup/frozen-candidate.json'")
namespace = {'__file__': str(freezer), '__name__': '__main__', 'baseline_source': baseline}
exec(compile(code, str(freezer), 'exec'), namespace)
project = namespace['game']
paths = ['core/app.gd', 'soundtrack/audio_world.gd', 'tests/test_startup_selected_owner.gd',
         'tests/test_startup_audio_loading.gd']
receipt = {'baseline': str(baseline), 'candidate': str(project), 'changes': {}}
for relative in paths:
    shutil.copyfile(root/'game'/relative, project/relative)
    original = baseline/relative
    receipt['changes'][relative] = {
        'before': hashlib.sha256(original.read_bytes()).hexdigest() if original.exists() else None,
        'after': hashlib.sha256((project/relative).read_bytes()).hexdigest()}
# The original control gets only the identical measurement fixtures.
for relative in paths[2:]:
    shutil.copyfile(root/'game'/relative, baseline/relative)
(evidence/'startup/candidate-change.json').write_text(json.dumps(receipt, indent=2)+'\n')
