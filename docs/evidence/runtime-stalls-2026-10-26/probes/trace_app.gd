extends "res://core/app.gd"
## Read-only timing overrides; all production behavior delegates to the parent.
var trace_sink: SceneTree

func _open_race_loading(track: NativeTrack = null, practice: bool = false) -> RaceLoading:
	var began: int = Time.get_ticks_usec()
	trace_sink.mark("cover_open_begin")
	var result: RaceLoading = super._open_race_loading(track,practice)
	trace_sink.span("cover_setup",began,{"points":track.route.size() if track != null else 0})
	return result

func _present_race_loading() -> bool:
	var began: int = Time.get_ticks_usec()
	var context: Dictionary = trace_sink.context()
	trace_sink.mark("cover_present_begin")
	trace_sink.render_group()
	var result: bool = await super._present_race_loading()
	trace_sink.span("covered_draw_wait",began,{"drawn":result,"entry":context})
	return result

func _race_menu_visible(value: bool) -> void:
	var began: int = Time.get_ticks_usec()
	super._race_menu_visible(value)
	if trace_sink != null: trace_sink.span("menu_visibility",began,{"visible":value})

func _prepare_night_lighting(loading_id: int, prepared_game: Node) -> Dictionary:
	var began: int = Time.get_ticks_usec()
	var result: Dictionary = await super._prepare_night_lighting(loading_id,prepared_game)
	trace_sink.span("night_preparation",began,result)
	return result

func _close_race_loading(expected_id: int = 0) -> void:
	var began: int = Time.get_ticks_usec()
	super._close_race_loading(expected_id)
	if trace_sink != null: trace_sink.span("cover_close",began)
