"""Select a reversible candidate only in the task-owned frozen project."""
import json,shutil,sys
from pathlib import Path
evidence=Path(__file__).resolve().parent
game=Path(json.loads((evidence/'frozen-project.json').read_text())['project'])
mode=sys.argv[1]
assert mode in ('before','prune','radiance')
for name in ('creator_road.gdshaderinc','bridge_road.gdshaderinc'):
    archive=evidence/'before/game/track'/name
    if not archive.exists(): shutil.copyfile(game/'track'/name,archive)
    include=archive.read_text()
    if mode=='radiance':
        line='  RADIANCE = winter_seam_radiance(NORMAL,VIEW,INV_VIEW_MATRIX,winter_seam_weight(finish,frost));'
        assert include.count(line)==1
        include=include.replace(line,'#ifndef BMT_NO_WINTER_SEAM_RADIANCE\n'+line+'\n#endif')
    (game/'track'/name).write_text(include,encoding='utf-8')
shutil.copyfile(evidence/'harness/shader_branch_probe.gd',game/'tests/shader_branch_probe.gd')
source=(evidence/'before/game/track/surface_shader_variants.gd').read_text()
if mode=='prune':
    anchor='\tvar key: String = source.sha256_text()'
    assert source.count(anchor)==1
    source=source.replace(anchor,'\tif compatibility and fold_flags:\n\t\tsource = preload("res://tests/shader_branch_probe.gd").reduce(source)\n'+anchor)
elif mode=='radiance':
    anchor='\tvar key: String = source.sha256_text()'
    assert source.count(anchor)==1
    source=source.replace(anchor,'\t# Godot records RADIANCE usage before eliminating constant-false branches.\n\t# Omit only the authored Winter seam write when its fixed flag is false.\n\t# Dynamic bridges and other renderers keep their original feature selection.\n\tif compatibility and fold_flags and source.contains("const bool winter_snow = false;"):\n\t\tsource = "#define BMT_NO_WINTER_SEAM_RADIANCE\\n"+source\n'+anchor)
(game/'track/surface_shader_variants.gd').write_text(source,encoding='utf-8')
print('Frozen candidate:',mode)
