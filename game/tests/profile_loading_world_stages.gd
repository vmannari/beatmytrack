extends SceneTree
## Main-thread world construction, with original cooperative scheduling.
var visual: NativeTrackVisual
var previous: String = ""
var mark: int = 0
var stages: Dictionary = {}
var rows: Array = []

func _initialize() -> void: run.call_deferred()
func observe() -> void:
	if not is_instance_valid(visual): return
	if visual.build_stage==previous: return
	var now: int = Time.get_ticks_usec()
	if not previous.is_empty(): stages[previous] = float(now-mark)/1000.0
	previous = visual.build_stage; mark = now

func run() -> void:
	root.position = Vector2i(10000,10000)
	process_frame.connect(observe)
	for fixture: String in ["res://../backend/tests/fixtures/verified_oval.json","res://tests/fixtures/star_spline_lap.json"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
		if document.has("document"): document = document.document
		document.theme = "pine"
		var track: NativeTrack = TrackCompiler.compile(document)
		var ground: Dictionary = preload("res://race/race_ground_preparation.gd").run(func() -> bool: return false,track)
		visual = NativeTrackVisual.new(); visual.profile_build = true; visual.cache_race_world = true; visual.persist_road_meshes = false
		var road_started: int = Time.get_ticks_usec()
		visual.race_road_packet = preload("res://editor/road_preparation.gd").prepare(track,true,false,func() -> bool: return false)
		print("ROAD_CPU_MS ",float(Time.get_ticks_usec()-road_started)/1000.0)
		root.add_child(visual)
		var began: int = Time.get_ticks_usec()
		previous = "initial"; mark = began; stages = {}
		await visual.build(track,ground.bridge,true)
		stages[previous] = float(Time.get_ticks_usec()-mark)/1000.0
		var result: Dictionary = {"fixture":fixture,"wall_ms":float(Time.get_ticks_usec()-began)/1000.0,"stages":stages.duplicate(),"costs":visual.build_costs,"nodes":visual.get_child_count(),"built":visual.world_built}
		rows.append(result); print("WORLD_STAGES ",JSON.stringify(result))
		visual.free(); visual = null
		await process_frame
	var path: String = OS.get_environment("BMT_LOADING_FIX_OUTPUT")
	DirAccess.make_dir_recursive_absolute(path)
	var file := FileAccess.open(path.path_join("world.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t")); file.close()
	quit()
