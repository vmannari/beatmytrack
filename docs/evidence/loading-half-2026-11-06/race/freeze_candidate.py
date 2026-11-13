"""Reuse the reviewed freezer against the immutable task baseline, then one patch."""
import hashlib
import json
from pathlib import Path
import shutil

evidence = Path(__file__).resolve().parent.parent
root = evidence.parents[2]
baseline = root/'build/loading-half-20261106/frozen-1793996701250524100/game'
freezer = evidence/'freeze_project.py'
code = freezer.read_text(encoding='utf-8')
code = code.replace("root/'game'", "baseline_source")
code = code.replace("root/'game/", "baseline_source/'")
code = code.replace("evidence/'frozen-project.json'", "evidence/'race/frozen-candidate.json'")
namespace = {'__file__':str(freezer),'__name__':'__main__','baseline_source':baseline}
exec(compile(code,str(freezer),'exec'),namespace)
project = namespace['game']
for relative in ['editor/editor_memory.gd','tests/test_race_effect_retention.gd']:
    shutil.copyfile(root/'game'/relative,project/relative)
receipt = {'baseline':str(baseline),'candidate':str(project),'changes':{}}
for relative in ['editor/editor_memory.gd','tests/test_race_effect_retention.gd']:
    old = baseline/relative
    receipt['changes'][relative] = {
        'before':hashlib.sha256(old.read_bytes()).hexdigest() if old.exists() else None,
        'after':hashlib.sha256((project/relative).read_bytes()).hexdigest()}
(evidence/'race/candidate-change.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
