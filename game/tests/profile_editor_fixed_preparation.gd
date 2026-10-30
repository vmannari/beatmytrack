extends "res://tests/test_editor_t01_t04.gd"
var stages: Dictionary = {}
var last_tick: int = 0
var last_stage: String = ""
func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	if last_tick != 0: stages[last_stage] = int(stages.get(last_stage,0))+now-last_tick
	last_tick = now; last_stage = "idle"
	if is_instance_valid(app):
		if app.editor_commits.unsettled(): last_stage = "analysis"
		elif app.editor_preview_thread != null: last_stage = "preview_worker"
		elif is_instance_valid(app.editor_world) and app.editor_world._building: last_stage = "visual"
	return false
func record(label: String, values: Dictionary) -> void:
	values["observed_stages_us"] = stages.duplicate(); stages.clear()
	if label.begins_with("practice_enter") and is_instance_valid(app.game):
		values["game_costs"] = app.game.preparation_costs
		if is_instance_valid(app.game.world_render_preparation):
			values["render_groups"] = app.game.world_render_preparation.frame_groups
			values["render_max_draw_us"] = app.game.world_render_preparation.draw_us_max
		values["covered_draw_ms"] = app.game.bridge_preparation_ms
	super.record(label,values)
func run() -> void:
	root.size = Vector2i(1280,720)
	node_added.connect(func(node: Node) -> void:
		if node.get_script() != null and node.get_script().resource_path == "res://core/app.gd": node.race_profile_enabled = true)
	var scalar: bool = "--script-streams" in OS.get_cmdline_user_args()
	preload("res://editor/road_sections.gd").native_streams = not scalar
	var suffix: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--run-label="): suffix = "-"+arg.trim_prefix("--run-label=")
	out = ProjectSettings.globalize_path("res://../docs/evidence/track-editor-fixes-2026-10-28/performance/"+RenderingServer.get_current_rendering_method()+"-"+("script" if scalar else "native")+suffix)
	DirAccess.make_dir_recursive_absolute(out)
	await app_loop()
	record("complete",{"checks":checks,"failures":failures,"static_bytes":OS.get_static_memory_usage()})
	await create_timer(0.3).timeout
	print("EDITOR_FIXED_PREPARATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
