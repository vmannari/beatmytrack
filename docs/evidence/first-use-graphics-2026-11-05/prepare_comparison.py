"""Adapt retained same-scene and first-draw controls inside the owned copy."""
import json
from pathlib import Path
evidence=Path(__file__).resolve().parent
game=Path(json.loads((evidence/'frozen-project.json').read_text())['project'])
baseline=(evidence/'before/game/track/surface_shader_variants.gd').read_text().replace('class_name SurfaceShaderVariants\n','')
(game/'tests/fixtures/first_use_before.gd.txt').write_text(baseline,encoding='utf-8')
probe=(game/'tests/probe_shader_variant_consolidation.gd').read_text().replace('shader_consolidation_before.gd.txt','first_use_before.gd.txt')
probe=probe.replace('FileAccess.get_file_as_string(path).replace(', 'FileAccess.get_file_as_string(path).replace("\\r\\n","\\n").replace(')
(game/'tests/probe_first_use_comparison.gd').write_text(probe,encoding='utf-8')
for old,new in [('review_shader_variant_consolidation.gd','review_first_use_comparison.gd'),('profile_variant_first_draw.gd','profile_first_use_comparison.gd')]:
    source=(game/'tests'/old).read_text().replace('probe_shader_variant_consolidation.gd','probe_first_use_comparison.gd')
    source=source.replace('OS.get_environment("BMT_VARIANT_FOLDER")','OS.get_environment("BMT_GRAPHICS_OUTPUT")')
    source=source.replace('OS.get_environment("BMT_VARIANT_OUTPUT")','OS.get_environment("BMT_GRAPHICS_OUTPUT").path_join("first-draw.json")')
    source=source.replace('OS.get_environment("BMT_VARIANT_THEMES")','OS.get_environment("BMT_GRAPHICS_THEMES")')
    source=source.replace('if OS.get_environment("BMT_VARIANT_FINAL") == "1":','if true:')
    (game/'tests'/new).write_text(source,encoding='utf-8')
print('Prepared task-start controls')
