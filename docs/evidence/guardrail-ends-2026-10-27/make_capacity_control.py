from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
source = (ROOT / 'game/tests/test_spline_barriers.gd').read_text(encoding='utf-8')
body = source[source.index('func geometry_cases()'):source.index('func settle()')]
assert body.count('document.objects.resize(94)') == 1
body = body.replace('document.objects.resize(94)', '''document.objects = []
		for fill: int in range(preload("res://editor/creator_limits.gd").MAX_OBJECTS-2): document.objects.append({"kind":"tyre_stack","position":[0.0,0.0],"rotation":0.0})''')
(Path(__file__).parent / 'spline_current_capacity.gd').write_text(
    'extends "res://tests/test_spline_barriers.gd"\n'
    '# Original assertions; fill current capacity with valid low-cost objects.\n' + body,
    encoding='utf-8')
