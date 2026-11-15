extends SceneTree
## Must run in a fresh process: preloading the builder would hide regressions.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ",label)

func run() -> void:
	for path: String in ["res://core/features/race.gd","res://core/game.tscn","res://race/selected_track_preparation.gd"]:
		var resource: Resource = load(path)
		check(resource != null,path+" loads")
		check(not ResourceLoader.has_cached("res://track/native_track_visual.gd"),path+" excludes construction")
	var document: Dictionary = load("res://editor/track_document.gd").create_default()
	document.theme = "winter"
	var track: Variant = load("res://editor/track_compiler.gd").compile(document)
	var winter: Script = load("res://track/winter_scenery.gd")
	var placements: Dictionary = winter.cover_data(track)
	check(not placements.is_empty(),"Winter CPU cover prepared")
	check(not ResourceLoader.has_cached("res://track/native_track_visual.gd"),"Winter placements exclude construction")
	var runtime: Node3D = load("res://track/prepared_race_world.gd").new()
	root.add_child(runtime)
	var bridge: Variant = load("res://track/bridge_presentation.gd").new(track)
	check(not await runtime.restore(track,bridge,true),"missing artifact requests fallback")
	check(not runtime.world_built and runtime.get_child_count() == 0,"miss leaves no partially built world")
	check(not ResourceLoader.has_cached("res://track/native_track_visual.gd"),"miss detection excludes construction")
	runtime.free()
	# Loading the fallback afterward must preserve deterministic CPU placements.
	var builder: Node3D = load("res://track/native_track_visual.gd").new()
	var sites: Array = load("res://track/scenery_placement.gd").sites(track,3)
	check(sites == builder._scenery_sites(track,3),"shared placement ordering")
	check(placements == winter.cover_data(track),"cover independent of builder initialization")
	builder.free()
	print("RACE_RUNTIME_DEPENDENCIES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
