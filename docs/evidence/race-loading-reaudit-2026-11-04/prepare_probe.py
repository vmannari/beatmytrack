"""Create a timestamp-only adapter for the extracted App race controller."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
old = (ROOT / 'game/tests/review_race_loading_2026_11_02.gd').read_text(encoding='utf-8')
start = old.index('func instrumented_app()')
end = old.index('\nfunc verify(', start)
adapter = '''var race_probe: GDScript

func instrumented_app() -> GDScript:
	var source := FileAccess.get_file_as_string("res://core/features/race.gd").replace("\\r\\n","\\n")
	var start := source.find("func run_start_race(app:")
	var end := source.find("\\nfunc run_race_installation_current(",start)
	if start < 0 or end <= start: push_error("Missing controller race function"); return null
	var body := source.substr(start,end-start)
	var hooks := [
		["\\tif not await app._await_selected_preparation(track,","selected_wait_begin"],
		["\\tvar daily_rules: RefCounted","selected_wait_end"],
		["\\tvar prepared_roads: Dictionary = {}","roads_begin"],
		["\\tapp.returning_to_editor = from_editor","roads_end"],
		["\\tapp.add_child(app.game)\\n\\tvar prepared_game: Node = app.game","game_begin"],
		["\\tif is_instance_valid(prepared_game.world_render_preparation):","game_end"],
		["\\t\\tif not await prepared_game.world_render_preparation.prepare(","graphics_begin"],
		["\\tapp.game.opponent_ghost =","graphics_end"],
		["\\tvar preparation_started: int = Time.get_ticks_usec()","effects_begin"],
		["\\tvar preparation_ms: float = (Time.get_ticks_usec() - preparation_started)","effects_end"],
		["\\tapp._close_race_loading(loading_id)\\n\\n","race_end"],
	]
	for hook: Array in hooks:
		var needle: String = hook[0]
		if body.count(needle) != 1: push_error("Review anchor changed: "+str(hook[1])); return null
		var indent := "\\t\\t" if needle.begins_with("\\t\\t") else "\\t"
		body = body.replace(needle,indent+"app._load_probe_mark(\\\""+str(hook[1])+"\\\")\\n"+needle)
	source = source.substr(0,start)+body+source.substr(end)
	race_probe = GDScript.new()
	race_probe.source_code = source
	if race_probe.reload() != OK: push_error("Review controller failed to compile"); return null
	source = FileAccess.get_file_as_string(APP_PATH).replace("\\r\\n","\\n")
	var needle := "var resource: Resource = load(path)"
	if source.count(needle) != 1: push_error("Feature load anchor changed"); return null
	source = source.replace(needle,"var resource: Resource = _load_probe_race if path == \\\"res://core/features/race.gd\\\" else load(path)")
	source += "\\nvar _load_probe_race: GDScript\\nvar _load_probe_marks: Array = []\\nfunc _load_probe_mark(label: String) -> void:\\n\\t_load_probe_marks.append({\\\"name\\\":label,\\\"us\\\":Time.get_ticks_usec()})\\n"
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK: push_error("Review App failed to compile"); return null
	return script
'''
new = old[:start] + adapter + old[end:]
new = new.replace('app = script.new()', 'app = script.new()\n\tapp._load_probe_race = race_probe')
new = new.replace('"world_cache_entries":WORLDS.entries.size()', '"feature_load_ms":app.feature_load_ms.duplicate(true),"world_cache_entries":WORLDS.entries.size()')
new = new.replace('var last_cache_state: Array = []', 'var last_cache_state: Array = []\nvar last_stage: String = ""\nvar stages: Array = []')
new = new.replace('var state: Array = [WORLDS.entries.size(),WORLDS.bytes_used(),app.editor_memory.trims]', '''var phase: String = str(app._load_probe_marks.back().name) if not app._load_probe_marks.is_empty() else "menu"
	if is_instance_valid(app.game):
		var world: Node = app.game.get_node_or_null("World")
		if world != null:
			for child: Node in world.get_children():
				if child is NativeTrackVisual: phase += ":"+child.build_stage; break
	if current_case+phase != last_stage:
		last_stage = current_case+phase
		var mark := {"case":current_case,"phase":phase,"us":Time.get_ticks_usec()}
		stages.append(mark)
		print("REVIEW_STAGE ",JSON.stringify(mark))
	var effect_bytes: int = preload("res://vehicle/effect_render_preparation.gd").cache_bytes(app)
	var state: Array = [WORLDS.entries.size(),WORLDS.bytes_used(),app.editor_memory.trims,effect_bytes]''')
new = new.replace('"telemetry":app.editor_memory.telemetry.duplicate(true)', '"telemetry":app.editor_memory.telemetry.duplicate(true),"instant_retained":preload("res://editor/editor_memory.gd").retained(app)')
new = new.replace('"cache_events":cache_events}', '"cache_events":cache_events,"stages":stages}')
new = new.replace('var cycles: int = 3', 'var cycles: int = 3\n\tvar dwell_ms: int = 0')
new = new.replace('for argument: String in OS.get_cmdline_user_args():', 'for argument: String in OS.get_cmdline_user_args():\n\t\tif argument.begins_with("--dwell-ms="): dwell_ms = clampi(argument.trim_prefix("--dwell-ms=").to_int(),0,3000)')
new = new.replace('app._leave_race()\n\t\t\tawait process_frame', 'app._leave_race()\n\t\t\tawait process_frame\n\t\t\tif dwell_ms > 0: await create_timer(dwell_ms/1000.0).timeout')
new = new.replace('"cache_events":cache_events,"stages":stages}', '"cache_events":cache_events,"stages":stages,"dwell_ms":dwell_ms}')
(ROOT / 'game/tests/review_race_loading_2026_11_04.gd').write_text(new, encoding='utf-8')

runner = (ROOT / 'docs/evidence/loading-review-2026-11-04/run_review.py').read_text(encoding='utf-8')
runner = runner.replace('build/loading-review-20261104', 'build/race-loading-reaudit-20261104')
runner = runner.replace("and path.suffix in ('.gd', '.gdshader', '.gdshaderinc', '.tscn')", "and path.suffix in ('.gd', '.gdshader', '.gdshaderinc', '.tscn', '.scn')")
runner = runner.replace("p.add_argument('--profile'", "p.add_argument('--frozen', action='store_true')\np.add_argument('--profile'")
runner = runner.replace("root = evidence.parents[2]", "root = evidence.parents[2]\nproject = Path(json.loads((evidence/'frozen-project.json').read_text())['project']) if args.frozen else root/'game'")
runner = runner.replace("str(root/'game')", "str(project)").replace("(root/'game').rglob", "project.rglob").replace("paths.append(root/'game/project.godot')", "paths.append(project/'project.godot')").replace("str(path.relative_to(root))", "str(path.relative_to(project))")
(Path(__file__).parent / 'run_review.py').write_text(runner, encoding='utf-8')
freeze = (ROOT / 'docs/evidence/startup-shell-2026-11-04/freeze_project.py').read_text(encoding='utf-8')
freeze = freeze.replace('build/startup-shell-20261104', 'build/race-loading-reaudit-20261104')
(Path(__file__).parent / 'freeze_project.py').write_text(freeze, encoding='utf-8')
