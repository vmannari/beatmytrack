"""Timestamp-only draw hooks in the owned frozen sources, never shipping code."""
import hashlib,json,shutil
from pathlib import Path
evidence=Path(__file__).resolve().parent
root=evidence.parents[2]
game=Path(json.loads((evidence/'frozen-project.json').read_text())['project'])
assert game.resolve().is_relative_to((root/'build/first-use-graphics-20261105').resolve())
shutil.copyfile(evidence/'harness/graphics_probe.gd',game/'tests/graphics_probe.gd')
shutil.copyfile(root/'game/tests/profile_first_use_graphics.gd',game/'tests/profile_first_use_graphics.gd')
patches={
 'race/world_render_preparation.gd':[
  ('\t\tvar drawn: bool = await draw.call()', '\t\tvar diagnostic: Dictionary = preload("res://tests/graphics_probe.gd").begin("world",submitted)\n\t\tvar drawn: bool = await draw.call()\n\t\tpreload("res://tests/graphics_probe.gd").end(diagnostic,drawn)')],
 'vehicle/effect_render_preparation.gd':[
  ('\t\tif not draw.is_valid() or not bool(await draw.call()): return prepared', '\t\tvar diagnostic: Dictionary = preload("res://tests/graphics_probe.gd").begin("particles",batch)\n\t\tif not draw.is_valid() or not bool(await draw.call()): return prepared\n\t\tpreload("res://tests/graphics_probe.gd").end(diagnostic,true)')]
}
receipts=[]
for name,changes in patches.items():
    source=(evidence/'before/game'/name).read_text()
    for before,after in changes:
        assert source.count(before)==1,(name,before)
        source=source.replace(before,after)
    (game/name).write_text(source,encoding='utf-8')
    receipts.append({'path':name,'sha256':hashlib.sha256((game/name).read_bytes()).hexdigest()})
dll=(evidence/'harness/program_probe.dll').as_posix()
(evidence/'harness/program_probe.gdextension').write_text('[configuration]\nentry_symbol="program_probe_init"\ncompatibility_minimum="4.7"\n[libraries]\nwindows.debug.x86_64="'+dll+'"\nwindows.release.x86_64="'+dll+'"\n')
(evidence/'probe-receipts.json').write_text(json.dumps(receipts,indent=2)+'\n')
print('Installed isolated native/draw diagnostics.')
