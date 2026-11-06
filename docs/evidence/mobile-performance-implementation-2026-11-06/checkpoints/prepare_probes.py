"""Owned copies keep historical outputs untouched and exercise installed disk layouts."""
from pathlib import Path
import json
import re

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
PROJECT = Path(json.loads((OUT / 'frozen-project.json').read_text())['project'])
HELPER = '''
func _prime_persistent(track: NativeTrack) -> void:
	var cache: GDScript = preload("res://race/checkpoint_layout_cache.gd")
	var disk: GDScript = preload("res://race/checkpoint_layout_disk_cache.gd")
	var versions: Array = [RaceRules.KEY,TrackSession.NOTICE_LAYOUT_VERSION,RaceRules.CHECKPOINT_LAYOUT_VERSION]
	var session := TrackSession.new()
	session._configure(track)
	var expected: PackedByteArray = var_to_bytes(track._race_gates)
	var key: String = cache.key_for(track,versions)
	check(disk.write_entry(key,track._race_gates,track,versions,func() -> bool: return false),"persist exact test layout")
	track._race_gates = {}; cache.trim_to()
	track._race_gates = disk.read_entry(key,track,versions)
	check(not track._race_gates.is_empty() and var_to_bytes(track._race_gates) == expected,"all gate decisions below use exact disk-restored layout")
'''

for name in ['test_checkpoint_road_coverage.gd', 'test_hairpin_checkpoints.gd', 'test_star_checkpoint_shortcuts.gd']:
    text = (ROOT/'game/tests'/name).read_text()
    text = re.sub(r'const (OUTPUT|EVIDENCE) := "[^"]+"', r'var \1: String = OS.get_environment("BMT_GRAPHICS_OUTPUT")+"/"', text)
    text = text.replace('"res://../docs/evidence/hairpin-checkpoints-2026-10-18/shortcut-sweep.json"', 'OS.get_environment("BMT_GRAPHICS_OUTPUT").path_join("shortcut-sweep.json")')
    text = re.sub(r'^(\s*)(var (\w+): NativeTrack = TrackCompiler\.compile\([^\n]+\))$', lambda m:m.group(0)+'\n'+m.group(1)+'_prime_persistent('+m.group(3)+')', text, flags=re.M)
    (PROJECT/'tests'/name.replace('.gd','_persistent.gd')).write_text(text+HELPER, newline='\n')

# Existing five-lap recorder writes inside this owned frozen build; point its
# output at the individual run receipt as well for easier review.
base = PROJECT/'tests/test_star_gate_tolerance.gd'
text = base.read_text().replace('ProjectSettings.globalize_path("res://../build/hairpin-checkpoints-2026-10-18")', 'OS.get_environment("BMT_GRAPHICS_OUTPUT")')
base.write_text(text, newline='\n')
print(PROJECT)
