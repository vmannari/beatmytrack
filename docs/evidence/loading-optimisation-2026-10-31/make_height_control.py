from pathlib import Path

root = Path(__file__).resolve().parents[3]
source = (root / 'game/tests/test_grass_road_height.gd').read_text(encoding='utf-8')
old = 'const HEIGHT = preload("res://track/road_surface_height.gd")'
assert source.count(old) == 1
source = source.replace(old, 'var HEIGHT: GDScript = old_height()')
assert source.count('BridgePresentation.new(track)') == 1
source = source.replace('BridgePresentation.new(track)', 'old_bridge(track)')
source += '''
func old_height() -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tests/fixtures/loading_road_support_before.gd.txt")
	assert(script.reload() == OK)
	return script

func old_bridge(track: NativeTrack) -> BridgePresentation:
	var bridge := BridgePresentation.new(track)
	bridge.road_surface = HEIGHT.new(track)
	return bridge
'''
(root / 'game/tests/test_loading_height_control.gd').write_text(source, encoding='utf-8')
(Path(__file__).parent / 'height-control.gd.txt').write_text(source, encoding='utf-8')
